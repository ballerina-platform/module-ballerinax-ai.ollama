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

import ballerina/ai;
import ballerina/test;

const SERVICE_URL = "http://localhost:8080/llm";
const API_KEY = "not-a-real-api-key";
const ERROR_MESSAGE = "Error occurred while attempting to parse the response from the LLM as the expected type. Retrying and/or validating the prompt could fix the response.";
const RUNTIME_SCHEMA_NOT_SUPPORTED_ERROR_MESSAGE = "Runtime schema generation is not yet supported";

final ModelProvider ollamaProvider = check new ("llama2", SERVICE_URL, {seed: 11});

@test:Config
function testGenerateMethodWithBasicReturnType() returns ai:Error? {
    int|error rating = ollamaProvider->generate(`Rate this blog out of 10.
        Title: ${blog1.title}
        Content: ${blog1.content}`);

    if rating is error {
        test:assertFail(rating.message());
    }
    test:assertEquals(rating, 4);
}

@test:Config
function testGenerateMethodWithBasicArrayReturnType() returns ai:Error? {
    int[]|error rating = ollamaProvider->generate(`Evaluate this blogs out of 10.
        Title: ${blog1.title}
        Content: ${blog1.content}

        Title: ${blog1.title}
        Content: ${blog1.content}`);

    if rating is error {
        test:assertFail(rating.message());
    }
    test:assertEquals(rating, [9, 1]);
}

@test:Config
function testGenerateMethodWithRecordReturnType() returns error? {
    Review|error result = ollamaProvider->generate(`Please rate this blog out of 10.
        Title: ${blog2.title}
        Content: ${blog2.content}`);
    if result is error {
        test:assertFail(result.message());
    }
    test:assertEquals(result, check review.fromJsonStringWithType(Review));
}

@test:Config
function testGenerateMethodWithTextDocument() returns ai:Error? {
    ai:TextDocument blog = {
        content: string `Title: ${blog1.title} Content: ${blog1.content}`
    };
    int maxScore = 10;

    int|error rating = ollamaProvider->generate(`How would you rate this ${"blog"} content out of ${maxScore}. ${blog}.`);
    if rating is error {
        test:assertFail(rating.message());
    }
    test:assertEquals(rating, 4);
}

@test:Config
function testGenerateMethodWithTextDocument2() returns error? {
    ai:TextDocument blog = {
        content: string `Title: ${blog1.title} Content: ${blog1.content}`
    };
    int maxScore = 10;

    Review|error result = ollamaProvider->generate(`How would you rate this text blog out of ${maxScore}, ${blog}.`);
    if result is error {
        test:assertFail(result.message());
    }

    test:assertEquals(result, check review.fromJsonStringWithType(Review));
}

type ReviewArray Review[];

@test:Config
function testGenerateMethodWithTextDocumentArray() returns error? {
    ai:TextDocument blog = {
        content: string `Title: ${blog1.title} Content: ${blog1.content}`
    };
    ai:TextDocument[] blogs = [blog, blog];
    int maxScore = 10;
    Review r = check review.fromJsonStringWithType(Review);

    ReviewArray|error result = ollamaProvider->generate(`How would you rate this text blogs out of ${maxScore}. ${blogs}. Thank you!`);
    if result is error {
        test:assertFail(result.message());
    }
    test:assertEquals(result, [r, r]);
}

@test:Config
function testGenerateMethodWithRecordArrayReturnType() returns error? {
    int maxScore = 10;
    Review r = check review.fromJsonStringWithType(Review);

    ReviewArray|error result = ollamaProvider->generate(`Please rate this blogs out of ${maxScore}.
        [{Title: ${blog1.title}, Content: ${blog1.content}}, {Title: ${blog2.title}, Content: ${blog2.content}}]`);

    if result is error {
        test:assertFail(result.message());
    }
    test:assertEquals(result, [r, r]);
}

@test:Config
function testGenerateMethodWithImageDocument() returns ai:Error? {
    ai:ImageDocument img = {
        content: sampleBinaryData
    };

    ai:ImageDocument img2 = {
        content: "https://example.com/sample-image.jpg"
    };

    string|error description = ollamaProvider->generate(`Describe the following image.${img}.`);
    test:assertEquals(description, "This is a sample image description.");

    // Ollama does not support URL-based images
    description = ollamaProvider->generate(`Describe this image.${img2}.`);
    if description !is error {
        test:assertFail("Expected error for URL-based image");
    }
    test:assertTrue(description.message().includes(
        "Ollama does not support URL-based images"));
}

@test:Config
function testGenerateMethodWithTextChunk() returns ai:Error? {
    ai:TextChunk chunk = {'type: "text-chunk", content: string `Title: ${blog1.title} Content: ${blog1.content}`};

    int|error rating = ollamaProvider->generate(`Rate this text chunk out of 10. ${chunk}.`);
    test:assertEquals(rating, 4);
}

@test:Config
function testGenerateMethodWithTextChunkArray() returns ai:Error? {
    ai:TextChunk chunk1 = {'type: "text-chunk", content: string `Title: ${blog1.title} Content: ${blog1.content}`};
    ai:TextChunk chunk2 = {'type: "text-chunk", content: string `Title: ${blog1.title} Content: ${blog1.content}`};

    int[]|error ratings = ollamaProvider->generate(`Rate these text chunks out of 10. ${<ai:Chunk[]>[chunk1, chunk2]}. Thank you!`);
    test:assertEquals(ratings, [9, 1]);
}

@test:Config
function testGenerateMethodWithMixedDocumentAndChunkArray() returns ai:Error? {
    ai:TextDocument doc = {content: string `Title: ${blog1.title} Content: ${blog1.content}`};
    ai:TextChunk chunk = {'type: "text-chunk", content: string `Title: ${blog1.title} Content: ${blog1.content}`};

    int[]|error ratings = ollamaProvider->generate(`Rate these mixed documents out of 10. ${<(ai:Document|ai:Chunk)[]>[doc, chunk]}. Thank you!`);
    test:assertEquals(ratings, [9, 1]);
}

@test:Config
function testGenerateMethodWithInvalidDocument() returns ai:Error? {
    ai:AudioDocument aud = {
        content: sampleBinaryData
    };

    string|error description = ollamaProvider->generate(`Describe this image. ${aud}.`);
    if description is string {
        test:assertFail();
    }
    test:assertEquals(description.message(), "Only Text and Image Documents are currently supported.");
}

@test:Config
function testGenerateMethodWithInvalidBasicType() returns ai:Error? {
    boolean|error rating = ollamaProvider->generate(`What is ${1} + ${1}?`);
    if rating !is error {
        test:assertFail("Expected error for unsupported type");
    }
    test:assertTrue(rating.message().includes(ERROR_MESSAGE));
}

type ProductName record {|
    string name;
|};

@test:Config
function testGenerateMethodWithInvalidRecordType() returns ai:Error? {
    ProductName[]|map<string>|error rating = trap ollamaProvider->generate(
                `Tell me name and the age of the top 10 world class cricketers`);
    if rating !is error {
        test:assertFail("Expected error for unsupported type");
    }
    test:assertTrue(rating.message().includes(RUNTIME_SCHEMA_NOT_SUPPORTED_ERROR_MESSAGE),
        string `expected error message to contain: ${
            RUNTIME_SCHEMA_NOT_SUPPORTED_ERROR_MESSAGE
        }, but found ${rating.message()}`);
}

type ProductNameArray ProductName[];

@test:Config
function testGenerateMethodWithInvalidRecordArrayType2() returns ai:Error? {
    ProductNameArray|error rating = ollamaProvider->generate(
                `Tell me name and the age of the top 10 world class cricketers`);
    if rating !is error {
        test:assertFail("Expected error for unsupported type");
    }
    test:assertTrue(rating.message().includes(ERROR_MESSAGE));
}

type Cricketers record {|
    string name;
|};

type Cricketers1 record {|
    string name;
|};

type Cricketers2 record {|
    string name;
|};

type Cricketers3 record {|
    string name;
|};

type Cricketers4 record {|
    string name;
|};

type Cricketers5 record {|
    string name;
|};

type Cricketers6 record {|
    string name;
|};

type Cricketers7 record {|
    string name;
|};

type Cricketers8 record {|
    string name;
|};

@test:Config
function testGenerateMethodWithStringUnionNull() returns error? {
    string? result = check ollamaProvider->generate(`Give me a random joke`);
    test:assertTrue(result is string);
}

@test:Config
function testGenerateMethodWithRecUnionBasicType() returns error? {
    Cricketers|string result = check ollamaProvider->generate(`Give me a random joke about cricketers`);
    test:assertTrue(result is string);
}

@test:Config
function testGenerateMethodWithRecUnionNull() returns error? {
    Cricketers1? result = check ollamaProvider->generate(`Name a random world class cricketer in India`);
    test:assertTrue(result is Cricketers1);
}

@test:Config
function testGenerateMethodWithArrayOnly() returns error? {
    Cricketers2[] result = check ollamaProvider->generate(`Name 10 world class cricketers in India`);
    test:assertTrue(result is Cricketers2[]);
}

@test:Config
function testGenerateMethodWithArrayUnionBasicType() returns error? {
    Cricketers3[]|string result = check ollamaProvider->generate(`Name 10 world class cricketers as string`);
    test:assertTrue(result is Cricketers3[]);
}

@test:Config
function testGenerateMethodWithArrayUnionNull() returns error? {
    Cricketers4[]? result = check ollamaProvider->generate(`Name 10 world class cricketers`);
    test:assertTrue(result is Cricketers4[]);
}

@test:Config
function testGenerateMethodWithArrayUnionRecord() returns ai:Error? {
    Cricketers5[]|Cricketers6|error result = ollamaProvider->generate(`Name top 10 world class cricketers`);
    test:assertTrue(result is Cricketers5[]);
}

@test:Config
function testGenerateMethodWithArrayUnionRecord2() returns ai:Error? {
   Cricketers7[]|Cricketers8|error result = ollamaProvider->generate(`Name a random world class cricketer`);
    test:assertTrue(result is Cricketers8);
}

@test:Config
function testFallbackPlainTextContent() returns ai:Error? {
    string result = check ollamaProvider->generate(`What is the capital of France?`);
    test:assertEquals(result, "Paris");
}

@test:Config
function testFallbackJsonContent() returns error? {
    Review result = check ollamaProvider->generate(`Review this restaurant in detail`);
    test:assertEquals(result, {rating: 8, comment: "Great blog!"});
}

@test:Config
function testFallbackCodeFenceContent() returns error? {
    Review result = check ollamaProvider->generate(`Summarize and rate this article`);
    test:assertEquals(result, {rating: 8, comment: "Great blog!"});
}

@test:Config
function testFallbackCodeFenceWithTrailingText() returns error? {
    Review result = check ollamaProvider->generate(
        `Summarize and rate this blog post`);
    test:assertEquals(result, {rating: 8, comment: "Great blog!"});
}

@test:Config
function testFallbackIntArrayType() returns ai:Error? {
    int[] result = check ollamaProvider->generate(
        `List three numbers between 1 and 5`);
    test:assertEquals(result, [1, 3, 5]);
}

@test:Config
function testFallbackIntType() returns ai:Error? {
    int result = check ollamaProvider->generate(
        `How many continents are there`);
    test:assertEquals(result, 7);
}

@test:Config
function testFallbackFloatType() returns ai:Error? {
    float result = check ollamaProvider->generate(
        `What is the value of pi to 2 decimals`);
    test:assertEquals(result, 3.14);
}

@test:Config
function testFallbackBooleanType() returns ai:Error? {
    boolean result = check ollamaProvider->generate(`Is the earth round`);
    test:assertEquals(result, true);
}

@test:Config
function testFallbackEmptyContent() returns ai:Error? {
    string|error result = ollamaProvider->generate(`Translate this to French`);
    if result !is error {
        test:assertFail("Expected error for empty content");
    }
    test:assertEquals(result.message(), "No relevant response from the LLM");
}
