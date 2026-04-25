// Copyright (c) 2025 WSO2 LLC (http://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/ai;
import ballerina/ai.observe;
import ballerina/constraint;
import ballerina/http;

type ResponseSchema record {|
    map<json> schema;
    boolean isOriginallyJsonObject = true;
|};

const JSON_CONVERSION_ERROR = "FromJsonStringError";
const CONVERSION_ERROR = "ConversionError";
const ERROR_MESSAGE = "Error occurred while attempting to parse the response from the " +
    "LLM as the expected type. Retrying and/or validating the prompt could fix the response.";
const RESULT = "result";
const GET_RESULTS_TOOL = "getResults";
const FUNCTION = "function";
const NO_RELEVANT_RESPONSE_FROM_THE_LLM = "No relevant response from the LLM";

isolated function generateJsonObjectSchema(map<json> schema) returns ResponseSchema {
    string[] supportedMetaDataFields = ["$schema", "$id", "$anchor", "$comment", "title", "description"];

    if schema["type"] == "object" {
        return {schema};
    }

    map<json> updatedSchema = map from var [key, value] in schema.entries()
        where supportedMetaDataFields.indexOf(key) is int
        select [key, value];

    updatedSchema["type"] = "object";
    map<json> content = map from var [key, value] in schema.entries()
        where supportedMetaDataFields.indexOf(key) !is int
        select [key, value];

    updatedSchema["properties"] = {[RESULT]: content};

    return {schema: updatedSchema, isOriginallyJsonObject: false};
}

isolated function parseResponseAsType(string resp,
        typedesc<anydata> expectedResponseTypedesc, boolean isOriginallyJsonObject) returns anydata|error {
    if !isOriginallyJsonObject {
        map<json> respContent = check resp.fromJsonStringWithType();
        anydata|error result = trap respContent[RESULT].fromJsonWithType(expectedResponseTypedesc);
        if result is error {
            return handleParseResponseError(result);
        }
        return result;
    }

    anydata|error result = resp.fromJsonStringWithType(expectedResponseTypedesc);
    if result is error {
        return handleParseResponseError(result);
    }
    return result;
}

isolated function getExpectedResponseSchema(typedesc<anydata> expectedResponseTypedesc) returns ResponseSchema|ai:Error {
    // Restricted at compile-time for now.
    typedesc<json> td = checkpanic expectedResponseTypedesc.ensureType();
    return generateJsonObjectSchema(check generateJsonSchemaForTypedescAsJson(td));
}

isolated function getGetResultsTool(map<json> parameters) returns map<json>[] =>
    [
    {
        'type: FUNCTION,
        'function: {
            name: GET_RESULTS_TOOL,
            parameters: parameters,
            description: "Submit the final answer. Call this tool with your response in the result field."
        }
    }
];

type ChatContent record {|
    string text;
    string[] images;
|};

isolated function generateChatCreationContent(ai:Prompt prompt) returns ChatContent|ai:Error {
    string[] & readonly strings = prompt.strings;
    anydata[] insertions = prompt.insertions;
    string promptStr = "";
    string[] images = [];

    if strings.length() > 0 {
        promptStr += strings[0];
    }

    foreach int i in 0 ..< insertions.length() {
        anydata insertion = insertions[i];
        string str = strings[i + 1];

        if insertion is ai:Document {
            if insertion is ai:TextDocument {
                promptStr += insertion.content + " ";
            } else if insertion is ai:ImageDocument {
                images.push(check getImageBase64(insertion));
                promptStr += "[img]";
            } else {
                return error ai:Error("Only Text and Image Documents are currently supported.");
            }
        } else if insertion is ai:Document[] {
            foreach ai:Document doc in insertion {
                if doc is ai:TextDocument {
                    promptStr += doc.content + " ";
                } else if doc is ai:ImageDocument {
                    images.push(check getImageBase64(doc));
                    promptStr += "[img]";
                } else {
                    return error ai:Error("Only Text and Image Documents are currently supported.");
                }
            }
        } else {
            promptStr += insertion.toString();
        }
        promptStr += str;
    }

    promptStr += addToolDirective();
    return {text: promptStr.trim(), images};
}

isolated function getImageBase64(ai:ImageDocument doc) returns string|ai:Error {
    ai:Url|byte[] content = doc.content;
    if content is ai:Url {
        ai:Url|constraint:Error validationRes = constraint:validate(content);
        if validationRes is error {
            return error(validationRes.message(), validationRes.cause());
        }
        return content;
    }

    return content.toBase64();
}

isolated function addToolDirective() returns string {
    return "\nDo not respond with text. You must submit your response by calling the `getResults` tool.";
}

// Extracts content from markdown code fences (```json ... ``` or ``` ... ```).
// If multiple code blocks exist, the last one is used (models often put the actual 
// result there). If no code fences are found, returns the original content.
isolated function stripCodeFences(string content) returns string {
    int? lastFenceStart = content.lastIndexOf("```");
    if lastFenceStart is () {
        return content;
    }
    // Find the second-to-last ``` which is the opening fence of the last block
    string beforeLastFence = content.substring(0, lastFenceStart);
    int? openFenceStart = beforeLastFence.lastIndexOf("```");
    if openFenceStart is () {
        return content;
    }
    string fencedBlock = content.substring(openFenceStart);
    // Remove opening fence line (``` or ```json, etc.)
    int? firstNewline = fencedBlock.indexOf("\n");
    if firstNewline is () {
        return content;
    }
    string inner = fencedBlock.substring(firstNewline + 1);
    // Remove closing fence
    if inner.endsWith("```") {
        inner = inner.substring(0, inner.length() - 3);
    }
    return inner.trim();
}

isolated function handleParseResponseError(error chatResponseError) returns error {
    string msg = chatResponseError.message();
    if msg.includes(JSON_CONVERSION_ERROR) || msg.includes(CONVERSION_ERROR) {
        return error(string `${ERROR_MESSAGE}`, detail = chatResponseError);
    }
    return chatResponseError;
}

isolated function generateLlmResponse(http:Client llmClient, string modelType,
        readonly & map<json> modleParameters, ai:Prompt prompt,
        typedesc<json> expectedResponseTypedesc) returns anydata|ai:Error {
    observe:GenerateContentSpan span = observe:createGenerateContentSpan(modelType);
    span.addProvider("ollama");

    ChatContent chatContent;
    ResponseSchema responseSchema;
    do {
        chatContent = check generateChatCreationContent(prompt);
        responseSchema = check getExpectedResponseSchema(expectedResponseTypedesc);
    } on fail ai:Error err {
        span.close(err);
        return err;
    }

    map<json>[] tools = getGetResultsTool(responseSchema.schema);
    // Ollama does not support `tool_choice` to force tool calls, unlike some other providers.
    // A system message is used to nudge local models into calling the tool instead of
    // responding with plain text.
    map<json> systemMessage = {
        role: ai:SYSTEM,
        "content": string `You must always call the ${GET_RESULTS_TOOL
            } tool to submit your response. Never reply with plain text.`
    };
    map<json> userMessage = {role: ai:USER, "content": chatContent.text};
    if chatContent.images.length() > 0 {
        userMessage["images"] = chatContent.images;
    }
    map<json>[] messages = [systemMessage, userMessage];
    map<json> request = {
        messages,
        tools,
        model: modelType,
        'stream: false,
        options: {...modleParameters}
    };

    span.addInputMessages(messages);
    OllamaResponse|error response = llmClient->/api/chat.post(request);
    if response is error {
        ai:Error err = error("Error while connecting to ollama", response);
        span.close(err);
        return err;
    }

    int? inputTokens = response.prompt_eval_count;
    if inputTokens is int {
        span.addInputTokenCount(inputTokens);
    }
    int? outputTokens = response.eval_count;
    if outputTokens is int {
        span.addOutputTokenCount(outputTokens);
    }
    string? finishReason = response.done_reason;
    if finishReason is string {
        span.addFinishReason(finishReason);
    }

    OllamaToolCall[]? toolCalls = response.message?.tool_calls;
    string responseStr;
    if toolCalls is OllamaToolCall[] && toolCalls.length() > 0 {
        OllamaToolCall tool = toolCalls[0];
        map<json> arguments = tool.'function.arguments;
        responseStr = arguments.toJsonString();
    } else {
        // Fallback: when the model responds with text instead of a tool call,
        // attempt to parse the content directly. This is common with smaller
        // models that do not reliably use the tool-calling mechanism.
        string content = stripCodeFences(response.message.content.trim());
        if content == "" {
            ai:Error err = error(NO_RELEVANT_RESPONSE_FROM_THE_LLM);
            span.close(err);
            return err;
        }
        responseStr = responseSchema.isOriginallyJsonObject ? content :
            {[RESULT]: content}.toJsonString();
    }

    anydata|error res = parseResponseAsType(responseStr, expectedResponseTypedesc,
            responseSchema.isOriginallyJsonObject);
    if res is error {
        ai:Error err = error(string `Invalid value returned from the LLM Client, expected: '${
            expectedResponseTypedesc.toBalString()}', found '${res.toBalString()}'`);
        span.close(err);
        return err;
    }

    anydata|error result = res.ensureType(expectedResponseTypedesc);
    if result is error {
        ai:Error err = error(string `Invalid value returned from the LLM Client, expected: '${
            expectedResponseTypedesc.toBalString()}', found '${(typeof response).toBalString()}'`);
        span.close(err);
        return err;
    }
    span.addOutputMessages(result.toJson());
    span.addOutputType(observe:JSON);
    span.close();
    return result;
}
