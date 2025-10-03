// Copyright (c) 2025 WSO2 LLC. (http://www.wso2.org).
//
// WSO2 Inc. licenses this file to you under the Apache License,
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

isolated function getExpectedParameterSchema(string message) returns map<json> {
    if message.startsWith("Evaluate this") {
        return expectedParameterSchemaStringForRateBlog6;
    }

    if message.startsWith("Rate this blog") {
        return expectedParameterSchemaStringForRateBlog;
    }

    if message.startsWith("On a scale from 1 to 10") {
        return expectedParameterSchemaStringForRateBlog2;
    }

    if message.startsWith("What is the result of") {
        return {"type": "object", "properties": {"result": {"type": "integer"}}};
    }

    if message.startsWith("Please rate this blogs") {
        return expectedParameterSchemaStringForRateBlog5;
    }

    if message.startsWith("Please rate this blog") {
        return expectedParameterSchemaStringForRateBlog2;
    }

    if message.startsWith("What is 1 + 1?") {
        return expectedParameterSchemaStringForRateBlog3;
    }

    if message.startsWith("Tell me") {
        return expectedParameterSchemaStringForRateBlog4;
    }

    if message.startsWith("How would you rate this blog content") {
        return expectedParameterSchemaStringForRateBlog;
    }

    if message.startsWith("How would you rate this text blogs") {
        return expectedParameterSchemaStringForRateBlog5;
    }

    if message.startsWith("How would you rate this text blog") {
        return expectedParameterSchemaStringForRateBlog2;
    }

    if message.startsWith("Describe the following image.") {
        return expectedParameterSchemaStringForRateBlog9;
    }

    if message.startsWith("Describe this image.") {
        return expectedParameterSchemaStringForRateBlog9;
    }

    if message.startsWith("Describe these images.") {
        return expectedParameterSchemaStringForRateBlog8;
    }

    if message.startsWith("How do you rate this blog") {
        return expectedParameterSchemaStringForRateBlog7;
    }

    if message.startsWith("How would you rate this blog") {
        return expectedParameterSchemaStringForRateBlog2;
    }

    if message.startsWith("What's the output of the Ballerina code below?") {
        return expectedParamterSchemaStringForBalProgram;
    }

    if message.startsWith("Which country") {
        return expectedParamterSchemaStringForCountry;
    }

    if message.startsWith("Who is a popular sportsperson") {
        return {
            "type": "object",
            "properties": {
                "result": {
                    "oneOf": [
                        {
                            "type": "object",
                            "required": ["firstName", "middleName", "lastName", "yearOfBirth", "sport"],
                            "properties": {
                                "firstName": {"type": "string"},
                                "middleName": {"oneOf": [{"type": "string"}, {"type": "null"}]},
                                "lastName": {"type": "string"},
                                "yearOfBirth": {"type": "integer"},
                                "sport": {"type": "string"}
                            }
                        },
                        {"type": "null"}
                    ]
                }
            }
        };
    }

    if message.startsWith("Give me a random joke about cricketers") {
        return expectedParameterSchemaForRecUnionBasicType;
    }

    if message.startsWith("Give me a random joke") {
        return {"type":"object","properties":{"result":{"anyOf":[{"type":"string"},{"type":"null"}]}}};
    }

    if message.startsWith("Name a random world class cricketer in India") {
        return expectedParameterSchemaForRecUnionNull;
    }

    if message.startsWith("Name 10 world class cricketers in India") {
        return expectedParameterSchemaForArrayOnly;
    }

    if message.startsWith("Name 10 world class cricketers as string") {
        return expectedParameterSchemaForArrayUnionBasicType;
    }

    if message.startsWith("Name top 10 world class cricketers") {
        return expectedParameterSchemaForArrayUnionRec;
    }

    if message.startsWith("Name a random world class cricketer") {
        return expectedParameterSchemaForArrayUnionRec;
    }

    if message.startsWith("Name 10 world class cricketers") {
        return expectedParamSchemaForArrayUnionNull;
    }

    return {};
}

isolated function getInitialMockLlmResult(string message) returns map<json>|error {
    if message.startsWith("Evaluate this") {
        return {"result": [9, 1]};
    }

    if message.startsWith("Rate this blog") {
        return {"result": 4};
    }

    if message.startsWith("On a scale from 1 to 10") {
        return check review.fromJsonStringWithType();
    }

    if message.startsWith("What is the result of 1 + 4?") {
        return {result: 5};
    }

    if message.startsWith("What is the result of 1 + 5?") {
        return {result: 6};
    }

    if message.startsWith("What is the result of") {
        return {result: true};
    }

    if message.startsWith("Please rate this blogs") {
        map<json>|error reviewResult = review.fromJsonStringWithType();
        if reviewResult !is error {
            return {"result": [reviewResult, reviewResult]};
        }
    }

    if message.startsWith("Please rate this blog") {
        map<json>|error reviewResult = review.fromJsonStringWithType();
        if reviewResult !is error {
            return reviewResult;
        }
    }

    if message.startsWith("What is 1 + 1?") {
        return {"result": 2};
    }

    if message.startsWith("Tell me") {
        return {"result": [{"name": "Virat Kohli", "age": 33}, {"name": "Kane Williamson", "age": 30}]};
    }

    if message.startsWith("What's the output of the Ballerina code below?") {
        return {"result": 30};
    }

    if message.startsWith("Which country") {
        return {"result": "Sri Lanka"};
    }

    if message.startsWith("Who is a popular sportsperson") {
        return {"result": {"firstName": "Simone", "middleName": null,
            "lastName": "Biles", "yearOfBirth": 1997, "sport": "Gymnastics"}};
    }

    if message.startsWith("How would you rate this blog content") {
        return {"result": 4};
    }

    if message.startsWith("How do you rate this blog") {
        return {"result": 4};
    }

    if message.startsWith("How would you rate this text blogs") {
        map<json>|error reviewResult = review.fromJsonStringWithType();
        if reviewResult !is error {
            return {"result": [reviewResult, reviewResult]};
        }
    }

    if message.startsWith("How would you rate this text blog") {
        map<json>|error reviewResult = review.fromJsonStringWithType();
        if reviewResult !is error {
            return reviewResult;
        }
    }

    if message.startsWith("How would you rate this blog") {
        map<json>|error reviewResult = review.fromJsonStringWithType();
        if reviewResult !is error {
            return reviewResult;
        }
    }

    if message.startsWith("Describe the following image.") {
        return {"result": "This is a sample image description."};
    }

    if message.startsWith("Describe this image.") {
        return {"result": "This is a sample image description."};
    }

    if message.startsWith("Describe these images.") {
        return {"result": ["This is a sample image description.", "This is a sample image description."]};
    }
    
    if message.startsWith("Name a random world class cricketer in India") {
        return {"result": {"name": "Sanga"}};
    }

    if message.startsWith("Name a random world class cricketer") {
        return {"result": {"name": "Sanga"}};
    }

    if message.startsWith("Name 10 world class cricketers") {
        return {
            "result": [
                {"name": "Virat Kohli"},
                {"name": "Joe Root"},
                {"name": "Steve Smith"},
                {"name": "Kane Williamson"},
                {"name": "Babar Azam"},
                {"name": "Ben Stokes"},
                {"name": "Jasprit Bumrah"},
                {"name": "Pat Cummins"},
                {"name": "Shaheen Afridi"},
                {"name": "Rashid Khan"}
            ]
        };
    }

    if message.startsWith("Name top 10 world class cricketers") {
        return {
            "result": [
                {"name": "Virat Kohli"},
                {"name": "Joe Root"},
                {"name": "Steve Smith"},
                {"name": "Kane Williamson"},
                {"name": "Babar Azam"},
                {"name": "Ben Stokes"},
                {"name": "Jasprit Bumrah"},
                {"name": "Pat Cummins"},
                {"name": "Shaheen Afridi"},
                {"name": "Rashid Khan"}
            ]
        };
    }

    if message.startsWith("Give me a random joke") {
        return {"result": "This is a random joke"};
    }

    return error("Unexpected message for initial call");
}

isolated function getTestServiceResponse(string content, int retryCount = 0) returns OllamaResponse|error =>
    {
    model: "llama2",
    message: {
        content: "",
        role: "assistant",
        tool_calls: [
            {
                'function: {
                    name: GET_RESULTS_TOOL,
                    arguments: retryCount == 0 ?
                                check getInitialMockLlmResult(content) :
                                    retryCount == 1 ?
                                        check getFirstRetryLlmResult(content) :
                                        check getSecondRetryLlmResult(content)
                }
            }
        ]
    }
};

isolated function getFirstRetryLlmResult(string message) returns map<json>|error {
    if message.startsWith("What is the result of 1 + 1?") {
        return {result: "hi"};
    }

    if message.startsWith("What is the result of 1 + 2?") {
        return {result: null};
    }

    if message.startsWith("What is the result of 1 + 3?") {
        return {result: 4};
    }

    if message.startsWith("What is the result of 1 + 6?") {
        return {result: 7};
    }

    return error("Unexpected message for first retry call");
}

isolated function getSecondRetryLlmResult(string message) returns map<json>|error {
    if message.startsWith("What is the result of 1 + 1?") {
        return {result: 2};
    }

    if message.startsWith("What is the result of 1 + 2?") {
        return {result: 3};
    }

    return error("Unexpected message for second retry call");
}

isolated function generateConversionErrorMessage(string errorMessage) returns string =>
    string `The tool call for the function 'getResults' failed.
        Error: error("{ballerina/lang.value}ConversionError",message="${errorMessage}")
        You must correct the function arguments based on this error and respond with a valid tool call.`;

isolated function getExpectedContentPartsForFirstRetryCall(string message) returns string|error {
    if message.startsWith("What is the result of 1 + 1?")
        || message.startsWith("What is the result of 1 + 2?")
        || message.startsWith("What is the result of 1 + 3?")
        || message.startsWith("What is the result of 1 + 6?") {
        return generateConversionErrorMessage("'boolean' value cannot be converted to 'int'");
    }

    return error("Unexpected content parts for first retry call");
}

isolated function getExpectedContentPartsForSecondRetryCall(string message) returns string|error {
    if message.startsWith("What is the result of 1 + 1?") {
        return generateConversionErrorMessage("'string' value cannot be converted to 'int'");
    }

    if message.startsWith("What is the result of 1 + 2?") {
        return generateConversionErrorMessage("cannot convert '()' to type 'int'");
    }

    return error("Unexpected content parts for second retry call");
}

isolated function getExpectedPrompt(string message) returns string|error {
    if message.startsWith("Rate this blog") {
        return expectedPromptStringForRateBlog;
    }

    if message.startsWith("Evaluate this") {
        return expectedPromptStringForRateBlog10;
    }

    if message.startsWith("Please rate this blogs") {
        return expectedPromptStringForRateBlog7;
    }

    if message.startsWith("Please rate this blog") {
        return expectedPromptStringForRateBlog2;
    }

    if message.startsWith("What is 1 + 1?") {
        return expectedPromptStringForRateBlog3;
    }

    if message.startsWith("Tell me") {
        return expectedPromptStringForRateBlog4;
    }

    if message.startsWith("How would you rate this blog content") {
        return expectedPromptStringForRateBlog5;
    }

    if message.startsWith("How do you rate this blog") {
        return expectedPromptStringForRateBlog11;
    }

    if message.startsWith("How would you rate this text blogs") {
        return expectedPromptStringForRateBlog9;
    }

    if message.startsWith("How would you rate this text blog") {
        return expectedPromptStringForRateBlog8;
    }

    if message.startsWith("How would you rate this blog") {
        return expectedPromptStringForRateBlog6;
    }

    if message.startsWith("What's the output of the Ballerina code below?") {
        return expectedPromptStringForBalProgram;
    }

    if message.startsWith("Which country") {
        return expectedPromptStringForCountry;
    }

    if message.startsWith("Who is a popular sportsperson") {
        return string `Who is a popular sportsperson that was 
        born in the decade starting from 1990 with Simone in 
        their name?`;
    }

    if message.startsWith("Describe the following image.") {
        return string `Describe the following image. ${sampleStringData} .${"\n"}You must call the ${"`"}getResults${"`"} tool to obtain the correct answer.`;
    }

    if message.startsWith("Describe this image.") {
        return "Describe this image. https://example.com/sample-image.jpg .\nYou must call the `getResults` tool to obtain the correct answer.";
    }

    if message.startsWith("Describe these images.") {
        return string `Describe these images. ${sampleStringData}  https://example.com/sample-image.jpg .${"\n"}You must call the ${"`"}getResults${"`"} tool to obtain the correct answer.`;
    }
    
    if message.startsWith("Name 10 world class cricketers in India") {
        return "Name 10 world class cricketers in India\nYou must call the `getResults`" +
        " tool to obtain the correct answer.";
    }

    if message.startsWith("Name 10 world class cricketers as string") {
        return "Name 10 world class cricketers as string\nYou must call the `getResults`" +
        " tool to obtain the correct answer.";
    }

    if message.startsWith("Name 10 world class cricketers") {
        return "Name 10 world class cricketers\nYou must call the `getResults`" +
        " tool to obtain the correct answer.";
    }

    if message.startsWith("Name top 10 world class cricketers") {
        return "Name top 10 world class cricketers\nYou must call the `getResults`" +
        " tool to obtain the correct answer.";
    }

    if message.startsWith("Name a random world class cricketer in India") {
        return "Name a random world class cricketer in India\nYou must call the `getResults`" +
        " tool to obtain the correct answer.";
    }

    if message.startsWith("Name a random world class cricketer") {
        return "Name a random world class cricketer\nYou must call the `getResults`" +
        " tool to obtain the correct answer.";
    }

    if message.startsWith("Give me a random joke about cricketers") {
        return "Give me a random joke about cricketers\nYou must call the `getResults`" +
        " tool to obtain the correct answer.";
    }

    if message.startsWith("Give me a random joke") {
        return "Give me a random joke\nYou must call the `getResults`" +
        " tool to obtain the correct answer.";
    }

    if message.startsWith("On a scale from 1 to 10") {
        return string `On a scale from 1 to 10, how would you rank this blog?.
        Title: ${blog2.title}
        Content: ${blog2.content}${"\n"}You must call the ${"`"}getResults${"`"} tool to obtain the correct answer.`;
    }

    if message.startsWith("What is the result of 1 + 1?") {
        return "What is the result of 1 + 1?\nYou must call the `getResults`" +
        " tool to obtain the correct answer.";
    }

    if message.startsWith("What is the result of 1 + 2?") {
        return "What is the result of 1 + 2?\nYou must call the `getResults`" +
        " tool to obtain the correct answer.";
    }

    if message.startsWith("What is the result of 1 + 3?") {
        return "What is the result of 1 + 3?\nYou must call the `getResults`" +
        " tool to obtain the correct answer.";
    }

    if message.startsWith("What is the result of 1 + 4?") {
        return "What is the result of 1 + 4?\nYou must call the `getResults`" +
        " tool to obtain the correct answer.";
    }

    if message.startsWith("What is the result of 1 + 5?") {
        return "What is the result of 1 + 5?\nYou must call the `getResults`" +
        " tool to obtain the correct answer.";
    }

    if message.startsWith("What is the result of 1 + 6?") {
        return "What is the result of 1 + 6?\nYou must call the `getResults`" +
        " tool to obtain the correct answer.";
    }


    return error("Unexpected prompt");
}
