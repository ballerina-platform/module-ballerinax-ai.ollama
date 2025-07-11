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
    resource function post api/chat(map<json> payload)
                returns OllamaResponse|error {
        test:assertEquals(payload.model, "llama2");
        test:assertEquals(payload.options, {"mirostat":0, "mirostat_eta":0.1d, "mirostat_tau":5.0d, 
                "num_ctx":2048, "repeat_last_n":64, "repeat_penalty":1.1d, "temperature":0.8d, "seed":11,
                "num_predict":-1, "top_k":40, "top_p":0.9d, "min_p":0d});
        json[] messages = check payload.messages.ensureType();
        json message = messages[0];

        string content = check message.content.ensureType();
        test:assertEquals(content, getExpectedPrompt(content));
        test:assertEquals(message.role, "user");
        json[] tools = check payload.tools.ensureType();
        if tools.length() == 0 {
            test:assertFail("No tools in the payload");
        }

        json tool = check tools[0].ensureType();
        map<json> parameters = check (tool.'function?.parameters).ensureType();

        test:assertEquals(parameters, getExpectedParameterSchema(content), string `Test failed for prompt:- ${content}`);
        return getTestServiceResponse(content);
    }
}
