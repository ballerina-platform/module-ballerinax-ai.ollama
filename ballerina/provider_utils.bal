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
import ballerina/constraint;
import ballerina/http;
import ballerina/lang.runtime;

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

isolated function parseResponseAsType(map<json> resp,
        typedesc<anydata> expectedResponseTypedesc, boolean isOriginallyJsonObject) returns anydata|error {
    if !isOriginallyJsonObject {
        json resultValue = check resp.result;
        anydata|error result = trap resultValue.fromJsonWithType(expectedResponseTypedesc);
        if result is error {
            return handleParseResponseError(result);
        }
        return result;
    }

    anydata|error result = resp.fromJsonWithType(expectedResponseTypedesc);
    if result is error {
        return handleParseResponseError(result);
    }
    return result;
}

isolated function handleParseResponseError(error chatResponseError) returns error {
    string msg = chatResponseError.message();
    if msg.includes(JSON_CONVERSION_ERROR) || msg.includes(CONVERSION_ERROR) {
        return error(string `${ERROR_MESSAGE}`, chatResponseError);
    }
    return chatResponseError;
}

isolated function generateLlmResponse(http:Client llmClient, string modelType,
        readonly & map<json> modleParameters, ai:GeneratorConfig generatorConfig, ai:Prompt prompt,
        typedesc<anydata> expectedResponseTypedesc) returns anydata|ai:Error {
    string content = check generateChatCreationContent(prompt);
    ResponseSchema responseSchema = check getExpectedResponseSchema(expectedResponseTypedesc);
    map<json>[]|error tools = getGetResultsTool(responseSchema.schema);
    if tools is error {
        return error("Error while generating the tool: " + tools.message());
    }

    map<json> request = {
        messages: [
            {
                role: ai:USER,
                "content": content
            }
        ],
        tools,
        model: modelType,
        'stream: false,
        options: {...modleParameters}
    };

    [int, decimal] [count, interval] = check getRetryConfigValues(generatorConfig);

    return getLlmResponseWithRetries(llmClient, request, expectedResponseTypedesc,
            responseSchema.isOriginallyJsonObject, count, interval);
}

isolated function getLlmResponseWithRetries(http:Client llmClient,
        map<json> request,
        typedesc<anydata> expectedResponseTypedesc,
        boolean isOriginallyJsonObject, int retryCount, decimal retryInterval) returns anydata|ai:Error {

    OllamaResponse|error response = llmClient->/api/chat.post(request);
    if response is error {
        return error("Error while connecting to ollama", response);
    }

    OllamaToolCall[]? toolCalls = response.message?.tool_calls;

    if toolCalls is () || toolCalls.length() == 0 {
        return error(NO_RELEVANT_RESPONSE_FROM_THE_LLM);
    }

    OllamaToolCall tool = toolCalls[0];
    map<json> arguments = tool.'function.arguments;

    anydata|error result = handleResponseWithExpectedType(arguments, isOriginallyJsonObject, expectedResponseTypedesc);
    json[]|error history = request.messages.ensureType();
    if history is error {
        return error("Error while retrieving message history: " + history.message());
    }

    history.push({role: ai:ASSISTANT, "content": arguments});

    if result is error && retryCount > 0 {
        string|error repairMessage = getRepairMessage(result, tool.'function.name);
        if repairMessage is error {
            return error("Failed to generate a valid repair message: " + repairMessage.message());
        }

        history.push({
            role: ai:USER,
            "content": repairMessage
        });

        runtime:sleep(retryInterval);
        return getLlmResponseWithRetries(llmClient, request, expectedResponseTypedesc, isOriginallyJsonObject,
                retryCount - 1, retryInterval);
    }

    if result is anydata {
        return result;
    }

    return error(string `Invalid value returned from the LLM Client, expected: '${
            expectedResponseTypedesc.toBalString()}', found '${result.toBalString()}'`);
}

isolated function handleResponseWithExpectedType(map<json> arguments, boolean isOriginallyJsonObject,
        typedesc<anydata> expectedResponseTypedesc) returns anydata|error {
    anydata|error res = parseResponseAsType(arguments, expectedResponseTypedesc, isOriginallyJsonObject);
    if res is error {
        return res;
    }
    return res.ensureType(expectedResponseTypedesc);
}

isolated function getRepairMessage(error e, string functionName) returns string|error {
    error? cause = e.cause();
    if cause is () {
        return e;
    }

    return string `The tool call for the function '${functionName}' failed.
        Error: ${cause.toString()}
        You must correct the function arguments based on this error and respond with a valid tool call.`;
}

isolated function getExpectedResponseSchema(typedesc<anydata> expectedResponseTypedesc) returns ResponseSchema|ai:Error {
    // Restricted at compile-time for now.
    typedesc<json> td = checkpanic expectedResponseTypedesc.ensureType();
    return generateJsonObjectSchema(check generateJsonSchemaForTypedescAsJson(td));
}

isolated function getGetResultsTool(map<json> parameters) returns map<json>[]|error =>
    [
        {
            'type: FUNCTION,
            'function: {
                name: GET_RESULTS_TOOL,
                parameters: parameters,
                description: string `Required Tool to call with the response from a large language model (LLM) for a user prompt. 
                            This tool is mandatory for the LLM to return a response.`
            }
        }
    ];

isolated function generateChatCreationContent(ai:Prompt prompt) returns string|ai:Error {
    string[] & readonly strings = prompt.strings;
    anydata[] insertions = prompt.insertions;
    string promptStr = "";

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
                promptStr += check addImageContentPart(insertion);
            } else {
                return error ai:Error("Only Text and Image Documents are currently supported.");
            }
        } else if insertion is ai:Document[] {
            foreach ai:Document doc in insertion {
                if doc is ai:TextDocument {
                    promptStr += doc.content + " ";
                } else if doc is ai:ImageDocument {
                    promptStr += check addImageContentPart(doc);
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
    return promptStr.trim();
}

isolated function addImageContentPart(ai:ImageDocument doc) returns string|ai:Error {
    ai:Url|byte[] content = doc.content;
    if content is ai:Url {
        ai:Url|constraint:Error validationRes = constraint:validate(content);
        if validationRes is error {
            return error(validationRes.message(), validationRes.cause());
        }
        return string ` ${content} `;
    }

    return string ` ${content.toBase64()} `;
}

isolated function addToolDirective() returns string {
    return "\nYou must call the `getResults` tool to obtain the correct answer.";
}

isolated function getRetryConfigValues(ai:GeneratorConfig generatorConfig) returns [int, decimal]|ai:Error {
    ai:RetryConfig? retryConfig = generatorConfig.retryConfig;
    if retryConfig != () {
        int count = retryConfig.count;
        decimal? interval = retryConfig.interval;

        if count < 0 {
            return error("Invalid retry count: " + count.toString());
        }
        if interval < 0d {
            return error("Invalid retry interval: " + interval.toString());
        }

        return [count, interval ?: 0d];
    }
    return [0, 0d];
}
