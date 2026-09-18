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

const STREAM_SERVICE_URL = "http://localhost:8081/streaming";
const WEATHER_PROMPT = "weather in Colombo";
const CREATED_AT = "2025-01-01T00:00:00.000000Z";

final ModelProvider ollamaStreamProvider = check new ("llama2", STREAM_SERVICE_URL, {seed: 11});

// The content fragment carries a multi-byte character on purpose: the mock
// service slices the payload every 7 bytes, so the emoji straddles two reads.
final string TEXT_NDJSON = toNdjson([
    {model: "llama2", created_at: CREATED_AT, message: {role: "assistant", content: "Hello"}, done: false},
    {
        model: "llama2",
        created_at: CREATED_AT,
        message: {role: "assistant", content: ", 🌍 ", thinking: "pondering"},
        done: false
    },
    {model: "llama2", created_at: CREATED_AT, message: {role: "assistant", content: "world!"}, done: false},
    {
        model: "llama2",
        created_at: CREATED_AT,
        message: {role: "assistant", content: ""},
        done: true,
        done_reason: "stop",
        prompt_eval_count: 10,
        eval_count: 3
    }
]);

// Ollama emits each tool call fully formed and without an index, and reports
// `done_reason` "stop" even when the turn ended in tool calls.
final string TOOL_CALL_NDJSON = toNdjson([
    {
        model: "llama2",
        created_at: CREATED_AT,
        message: {
            role: "assistant",
            content: "",
            tool_calls: [{'function: {name: "getWeather", arguments: {city: "Colombo"}}}]
        },
        done: false
    },
    {
        model: "llama2",
        created_at: CREATED_AT,
        message: {
            role: "assistant",
            content: "",
            tool_calls: [{'function: {name: "getTime", arguments: {zone: "IST"}}}]
        },
        done: false
    },
    {
        model: "llama2",
        created_at: CREATED_AT,
        message: {role: "assistant", content: ""},
        done: true,
        done_reason: "stop",
        prompt_eval_count: 20,
        eval_count: 8
    }
]);

// A turn that ends in tool calls but is cut off by the token limit. Ollama would
// report "length" here, and that must survive the tool-call correction.
final string TOOL_CALL_CUT_OFF_NDJSON = toNdjson([
    {
        model: "llama2",
        created_at: CREATED_AT,
        message: {
            role: "assistant",
            content: "",
            tool_calls: [{'function: {name: "getWeather", arguments: {city: "Colombo"}}}]
        },
        done: false
    },
    {
        model: "llama2",
        created_at: CREATED_AT,
        message: {role: "assistant", content: ""},
        done: true,
        done_reason: "length"
    }
]);

final string LENGTH_NDJSON = toNdjson([
    {model: "llama2", created_at: CREATED_AT, message: {role: "assistant", content: "Hel"}, done: false},
    {
        model: "llama2",
        created_at: CREATED_AT,
        message: {role: "assistant", content: ""},
        done: true,
        done_reason: "length"
    }
]);

// Ollama also reports lifecycle reasons such as "load" and "unload", which have
// no counterpart in the `ai` enum.
final string UNKNOWN_DONE_REASON_NDJSON = toNdjson([
    {model: "llama2", created_at: CREATED_AT, message: {role: "assistant", content: "Hi"}, done: false},
    {
        model: "llama2",
        created_at: CREATED_AT,
        message: {role: "assistant", content: ""},
        done: true,
        done_reason: "load"
    }
]);

// Ollama reports a mid-stream failure as a bare `{"error": "..."}` object.
final string MID_STREAM_ERROR_NDJSON =
    toNdjson([{model: "llama2", created_at: CREATED_AT, message: {role: "assistant", content: "Hi"}, done: false}]) +
    "{\"error\":\"an unexpected error occurred\"}\n";

final string MALFORMED_NDJSON =
    toNdjson([{model: "llama2", created_at: CREATED_AT, message: {role: "assistant", content: "Hi"}, done: false}]) +
    "{not json}\n";

// Ends without a `done` chunk, as a connection cut mid-generation would.
final string TRUNCATED_NDJSON = toNdjson([
    {model: "llama2", created_at: CREATED_AT, message: {role: "assistant", content: "Par"}, done: false},
    {model: "llama2", created_at: CREATED_AT, message: {role: "assistant", content: "tial"}, done: false}
]);

isolated function toNdjson(json[] chunks) returns string {
    string[] lines = from json chunk in chunks
        select chunk.toJsonString();
    return string:'join("\n", ...lines) + "\n";
}

isolated function collectChunks(stream<ai:ChatMessageChunk, ai:Error?> chunks)
        returns ai:ChatMessageChunk[]|ai:Error {
    ai:ChatMessageChunk[] collected = [];
    record {|ai:ChatMessageChunk value;|}|ai:Error? next = chunks.next();
    while next !is ai:Error? {
        collected.push(next.value);
        next = chunks.next();
    }
    if next is ai:Error {
        return next;
    }
    return collected;
}

@test:Config
function testChatAsStreamTextDeltas() returns error? {
    stream<ai:ChatMessageChunk, ai:Error?> chunkStream = check ollamaStreamProvider->chatAsStream(
        [{role: ai:USER, content: "Say hello"}]);
    ai:ChatMessageChunk[] chunks = check collectChunks(chunkStream);

    test:assertEquals(chunks.length(), 4);

    string content = "";
    string reasoning = "";
    foreach ai:ChatMessageChunk chunk in chunks {
        // `role` is required on every chunk, not only the first.
        test:assertEquals(chunk.role, ai:ASSISTANT);
        content += chunk.content ?: "";
        reasoning += chunk.reasoning ?: "";
    }
    test:assertEquals(content, "Hello, 🌍 world!");
    test:assertEquals(reasoning, "pondering");

    // Only the terminal chunk carries a finish reason.
    test:assertEquals(chunks[0].finishReason, ());
    ai:ChatMessageChunk last = chunks[3];
    test:assertEquals(last.finishReason, ai:STOP);
}

@test:Config
function testChatAsStreamToolCalls() returns error? {
    stream<ai:ChatMessageChunk, ai:Error?> chunkStream = check ollamaStreamProvider->chatAsStream(
        [{role: ai:USER, content: string `What is the ${WEATHER_PROMPT}?`}]);
    ai:ChatMessageChunk[] chunks = check collectChunks(chunkStream);

    test:assertEquals(chunks.length(), 3);

    // Tool calls arrive on separate chunks and must be numbered by a running
    // index, so a consumer can accumulate fragments the same way it would for a
    // provider that splits the arguments across chunks.
    ai:ToolCallChunk[] first = check chunks[0].toolCalls.ensureType();
    test:assertEquals(first.length(), 1);
    test:assertEquals(first[0].index, 0);
    test:assertEquals(first[0].name, "getWeather");
    test:assertEquals(first[0].arguments, "{\"city\":\"Colombo\"}");

    ai:ToolCallChunk[] second = check chunks[1].toolCalls.ensureType();
    test:assertEquals(second.length(), 1);
    test:assertEquals(second[0].index, 1);
    test:assertEquals(second[0].name, "getTime");
    test:assertEquals(second[0].arguments, "{\"zone\":\"IST\"}");

    // Ollama reports "stop" here; the normalized chunk must say `tool_calls`.
    test:assertEquals(chunks[2].toolCalls, ());
    test:assertEquals(chunks[2].finishReason, ai:TOOL_CALLS);
}

@test:Config
function testGenerateAsStreamYieldsOnlyText() returns error? {
    stream<string, ai:Error?> textStream = check ollamaStreamProvider->generateAsStream(`Say hello`);
    string content = "";
    record {|string value;|}|ai:Error? next = textStream.next();
    while next !is ai:Error? {
        content += next.value;
        next = textStream.next();
    }
    if next is ai:Error {
        test:assertFail(next.message());
    }
    test:assertEquals(content, "Hello, 🌍 world!");
}

// `generateAsStream` must yield only text fragments, so a tool-call turn
// (no text content at all) must produce an empty stream rather than surface
// tool-call/finish-only chunks as text.
@test:Config
function testGenerateAsStreamSkipsNonTextChunks() returns error? {
    stream<string, ai:Error?> textStream =
        check ollamaStreamProvider->generateAsStream(`What is the ${WEATHER_PROMPT}?`);
    string content = check collectText(textStream);
    test:assertEquals(content, "");
}

// Guards the mapping bug where a single `ai:ChatUserMessage` — the shape
// `generateAsStream` builds internally — went onto the wire with role "tool".
@test:Config
function testStreamingSendsUserRoleOnTheWire() returns error? {
    stream<ai:ChatMessageChunk, ai:Error?> chunkStream =
        check ollamaStreamProvider->chatAsStream({role: ai:USER, content: "Say hello"});
    _ = check collectChunks(chunkStream);
    json[] sent = getLastStreamRequestMessages();
    test:assertEquals(sent.length(), 1);
    test:assertEquals(check sent[0].role, "user");
    test:assertEquals(check sent[0].content, "Say hello");

    stream<string, ai:Error?> textStream = check ollamaStreamProvider->generateAsStream(`Say hello`);
    _ = check collectText(textStream);
    json[] generated = getLastStreamRequestMessages();
    test:assertEquals(generated.length(), 1);
    test:assertEquals(check generated[0].role, "user");
}

// `role` is required on every chunk, even though Ollama only stamps it on the
// wire message and the normalized type carries no separate role-only chunk.
@test:Config
function testChatAsStreamEmitsRoleOnEveryChunk() returns error? {
    stream<ai:ChatMessageChunk, ai:Error?> chunkStream = check ollamaStreamProvider->chatAsStream(
        [{role: ai:USER, content: "Say hello"}]);
    ai:ChatMessageChunk[] chunks = check collectChunks(chunkStream);

    test:assertTrue(chunks.length() > 0);
    foreach int i in 0 ..< chunks.length() {
        test:assertEquals(chunks[i].role, ai:ASSISTANT, string `Chunk ${i} must carry the role`);
    }
}

// `content` is `()` for a chunk that carries no answer text; Ollama sends an
// empty string on the tool-call and terminal chunks instead.
@test:Config
function testChatAsStreamContentIsNilForNonContentChunks() returns error? {
    stream<ai:ChatMessageChunk, ai:Error?> chunkStream = check ollamaStreamProvider->chatAsStream(
        [{role: ai:USER, content: string `What is the ${WEATHER_PROMPT}?`}]);
    ai:ChatMessageChunk[] chunks = check collectChunks(chunkStream);

    foreach ai:ChatMessageChunk chunk in chunks {
        test:assertEquals(chunk.content, ());
    }
}

// A tool-calling turn that really ran into the token limit must keep `length`;
// reporting `tool_calls` there would hide the truncation.
@test:Config
function testChatAsStreamToolCallsCutOffByLength() returns error? {
    stream<ai:ChatMessageChunk, ai:Error?> chunkStream = check ollamaStreamProvider->chatAsStream(
        [{role: ai:USER, content: SCENARIO_TOOL_CALL_CUT_OFF}]);
    ai:ChatMessageChunk[] chunks = check collectChunks(chunkStream);

    test:assertEquals(chunks.length(), 2);
    ai:ToolCallChunk[] toolCalls = check chunks[0].toolCalls.ensureType();
    test:assertEquals(toolCalls.length(), 1);
    test:assertEquals(chunks[1].finishReason, ai:LENGTH);
}

@test:Config
function testChatAsStreamLengthFinishReason() returns error? {
    stream<ai:ChatMessageChunk, ai:Error?> chunkStream = check ollamaStreamProvider->chatAsStream(
        [{role: ai:USER, content: SCENARIO_LENGTH}]);
    ai:ChatMessageChunk[] chunks = check collectChunks(chunkStream);
    test:assertEquals(chunks[chunks.length() - 1].finishReason, ai:LENGTH);
}

// Ollama's lifecycle reasons ("load", "unload") have no `ai:FinishReason`
// counterpart and must map to `()` rather than failing the stream.
@test:Config
function testChatAsStreamUnknownDoneReason() returns error? {
    stream<ai:ChatMessageChunk, ai:Error?> chunkStream = check ollamaStreamProvider->chatAsStream(
        [{role: ai:USER, content: SCENARIO_UNKNOWN_DONE_REASON}]);
    ai:ChatMessageChunk[] chunks = check collectChunks(chunkStream);
    test:assertEquals(chunks[chunks.length() - 1].finishReason, ());
}

@test:Config
function testChatAsStreamNonOkStatus() {
    stream<ai:ChatMessageChunk, ai:Error?>|ai:Error result = ollamaStreamProvider->chatAsStream(
        [{role: ai:USER, content: SCENARIO_SERVER_ERROR}]);
    if result !is ai:Error {
        test:assertFail("Expected an error for a non-OK status");
    }
    test:assertTrue(result is ai:LlmConnectionError, "Expected an ai:LlmConnectionError");
    test:assertTrue(result.message().includes("non-OK status 500"), result.message());
    // The response body is surfaced so the caller can see why the model refused.
    test:assertTrue(result.message().includes("not found"), result.message());
}

@test:Config
function testChatAsStreamMidStreamError() returns error? {
    stream<ai:ChatMessageChunk, ai:Error?> chunkStream = check ollamaStreamProvider->chatAsStream(
        [{role: ai:USER, content: SCENARIO_MID_STREAM_ERROR}]);
    ai:ChatMessageChunk[]|ai:Error chunks = collectChunks(chunkStream);
    if chunks !is ai:Error {
        test:assertFail("Expected the mid-stream error object to fail the stream");
    }
    test:assertTrue(chunks.message().includes("an unexpected error occurred"), chunks.message());
    // A failed stream is terminal: it must not re-enter the read loop.
    test:assertEquals(chunkStream.next(), ());
}

@test:Config
function testChatAsStreamMalformedChunk() returns error? {
    stream<ai:ChatMessageChunk, ai:Error?> chunkStream = check ollamaStreamProvider->chatAsStream(
        [{role: ai:USER, content: SCENARIO_MALFORMED}]);
    ai:ChatMessageChunk[]|ai:Error chunks = collectChunks(chunkStream);
    if chunks !is ai:Error {
        test:assertFail("Expected a malformed chunk to fail the stream");
    }
    test:assertTrue(chunks is ai:LlmInvalidResponseError, "Expected an ai:LlmInvalidResponseError");
    test:assertEquals(chunkStream.next(), ());
}

// A stream that ends without a `done` chunk was cut short; reporting normal
// completion would pass a partial answer off as a whole one.
@test:Config
function testChatAsStreamTruncatedStreamFails() returns error? {
    stream<ai:ChatMessageChunk, ai:Error?> chunkStream = check ollamaStreamProvider->chatAsStream(
        [{role: ai:USER, content: SCENARIO_TRUNCATED}]);
    ai:ChatMessageChunk[]|ai:Error chunks = collectChunks(chunkStream);
    if chunks !is ai:Error {
        test:assertFail("Expected a truncated stream to fail");
    }
    test:assertTrue(chunks is ai:LlmInvalidResponseError, "Expected an ai:LlmInvalidResponseError");
    test:assertTrue(chunks.message().includes("ended before the final chunk"), chunks.message());
}

// `generateAsStream` surfaces the same truncation, rather than returning a
// short answer as if it were complete.
@test:Config
function testGenerateAsStreamTruncatedStreamFails() returns error? {
    stream<string, ai:Error?> textStream =
        check ollamaStreamProvider->generateAsStream(`${SCENARIO_TRUNCATED}`);
    string|ai:Error text = collectText(textStream);
    if text !is ai:Error {
        test:assertFail("Expected a truncated stream to fail");
    }
    test:assertTrue(text.message().includes("ended before the final chunk"), text.message());
}

// Abandoning a stream part way must release it, and closing twice must be a
// no-op rather than an error.
@test:Config
function testChatAsStreamCloseIsIdempotent() returns error? {
    stream<ai:ChatMessageChunk, ai:Error?> chunkStream = check ollamaStreamProvider->chatAsStream(
        [{role: ai:USER, content: "Say hello"}]);
    record {|ai:ChatMessageChunk value;|}|ai:Error? first = chunkStream.next();
    if first is ai:Error? {
        test:assertFail("Expected at least one chunk");
    }
    check chunkStream.close();
    check chunkStream.close();
    test:assertEquals(chunkStream.next(), ());
}

isolated function collectText(stream<string, ai:Error?> textStream) returns string|ai:Error {
    string content = "";
    record {|string value;|}|ai:Error? next = textStream.next();
    while next !is ai:Error? {
        content += next.value;
        next = textStream.next();
    }
    if next is ai:Error {
        return next;
    }
    return content;
}
