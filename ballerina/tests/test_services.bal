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

import ballerina/http;
import ballerina/test;

service /llm on new http:Listener(8080) {
    private map<int> retryCountMap = {};

    resource function post api/chat(map<json> payload) returns OllamaResponse|error {
        string initialContent = check validateOllamaPayload(payload, 0);
        return getTestServiceResponse(initialContent, 0);
    }

    resource function post retry\-test/api/chat(map<json> payload) returns OllamaResponse|error {
        json[] messages = check payload.messages.ensureType();
        string initialContent = check messages[0].content.ensureType();
        
        int index;
        lock {
            index = updateRetryCountMap(initialContent, self.retryCountMap);
        }
        _ = check validateOllamaPayload(payload, index);

        return getTestServiceResponse(initialContent, index);
    }
}

isolated function validateOllamaPayload(map<json> payload, int index) returns string|error {
    test:assertEquals(payload.model, "llama2");
    test:assertEquals(payload.options, {"mirostat": 0, "mirostat_eta": 0.1d, "mirostat_tau": 5.0d,
            "num_ctx": 2048, "repeat_last_n": 64, "repeat_penalty": 1.1d, "temperature": 0.8d, "seed": 11,
            "num_predict": -1, "top_k": 40, "top_p": 0.9d, "min_p": 0d});

    json[] tools = check payload.tools.ensureType();
    if tools.length() == 0 {
        test:assertFail("No tools in the payload");
    }
    map<json> parameters = check tools[0].'function?.parameters.ensureType();
    
    json[] messages = check payload.messages.ensureType();
    string initialContent = check messages[0].content.ensureType();

    test:assertEquals(parameters, getExpectedParameterSchema(initialContent), 
        string `Test failed for prompt:- ${initialContent}`);

    check assertMessages(messages, initialContent, index);
    return initialContent;
}

isolated function assertMessages(json[] messages, string initialText, int index) returns error? {
    if index == 0 {
        test:assertEquals(messages[0].role, "user");
        test:assertEquals(messages[0].content, check getExpectedPrompt(initialText));
        return;
    }

    if index == 1 {
        test:assertEquals(messages[2].content, check getExpectedContentPartsForFirstRetryCall(initialText),
            string `Prompt assertion failed for prompt starting with '${initialText}' 
                on first attempt of the retry`);
        return;
    }

    test:assertEquals(messages[4].content,check getExpectedContentPartsForSecondRetryCall(initialText),
            string `Prompt assertion failed for prompt starting with '${initialText}' on 
                second attempt of the retry`);
}

isolated function updateRetryCountMap(string initialText, map<int> retryCountMap) returns int {
    if retryCountMap.hasKey(initialText) {
        int index = retryCountMap.get(initialText) + 1;
        retryCountMap[initialText] = index;
        return index;
    }

    retryCountMap[initialText] = 0;
    return 0;
}
