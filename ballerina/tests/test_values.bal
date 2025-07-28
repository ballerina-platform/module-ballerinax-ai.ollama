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
import ballerina/lang.array;

type Blog record {
    string title;
    string content;
};

type Review record {|
    int rating;
    string comment;
|};

final readonly & byte[] sampleBinaryData = [0x01, 0x02, 0x03, 0x04, 0x05];
final readonly & string sampleStringData = array:toBase64(sampleBinaryData);

const blog1 = {
    // Generated.
    title: "Tips for Growing a Beautiful Garden",
    content: string `Spring is the perfect time to start your garden. 
        Begin by preparing your soil with organic compost and ensure proper drainage. 
        Choose plants suitable for your climate zone, and remember to water them regularly. 
        Don't forget to mulch to retain moisture and prevent weeds.`
};

const blog2 = {
    // Generated.
    title: "Essential Tips for Sports Performance",
    content: string `Success in sports requires dedicated preparation and training.
        Begin by establishing a proper warm-up routine and maintaining good form.
        Choose the right equipment for your sport, and stay consistent with training.
        Don't forget to maintain proper hydration and nutrition for optimal performance.`
};

const review = "{\"rating\": 8, \"comment\": \"Talks about essential aspects of sports performance " +
        "including warm-up, form, equipment, and nutrition.\"}";
const reviewRecord = {
    rating: 8,
    comment: "Talks about essential aspects of sports performance including warm-up, form, equipment, and nutrition."
};

final string expectedPromptStringForRateBlog = string `Rate this blog out of 10.
        Title: ${blog1.title}
        Content: ${blog1.content}${"\n"}You must call the ${"`"}getResults${"`"} tool to obtain the correct answer.`;

final string expectedPromptStringForRateBlog2 = string `Please rate this blog out of 10.
        Title: ${blog2.title}
        Content: ${blog2.content}${"\n"}You must call the ${"`"}getResults${"`"} tool to obtain the correct answer.`;

const expectedPromptStringForRateBlog3 = string `What is 1 + 1?${"\n"}You must call the ${"`"}getResults${"`"} tool to obtain the correct answer.`;

const expectedPromptStringForRateBlog4 = string `Tell me name and the age of the top 10 world class cricketers${"\n"}You must call the ${"`"}getResults${"`"} tool to obtain the correct answer.`;

final string expectedPromptStringForRateBlog5 =
        string `How would you rate this blog content out of 10. Title: ${blog1.title} Content: ${blog1.content} .${"\n"}You must call the ${"`"}getResults${"`"} tool to obtain the correct answer.`;

final string expectedPromptStringForRateBlog6 =
        string `How would you rate this blog out of 10. Title: ${blog1.title} Content: ${blog1.content}${"\n"}You must call the ${"`"}getResults${"`"} tool to obtain the correct answer.`;

final string expectedPromptStringForRateBlog7 =
        string `Please rate this blogs out of 10.
        [{Title: ${blog1.title}, Content: ${blog1.content}}, {Title: ${blog2.title}, Content: ${blog2.content}}]${"\n"}You must call the ${"`"}getResults${"`"} tool to obtain the correct answer.`;

final string expectedPromptStringForRateBlog8 =
    string `How would you rate this text blog out of 10, Title: ${blog1.title} Content: ${blog1.content} .${"\n"}You must call the ${"`"}getResults${"`"} tool to obtain the correct answer.`;

final string expectedPromptStringForRateBlog9 = string
    `How would you rate this text blogs out of 10. Title: ${blog1.title} Content: ${blog1.content} Title: ${blog1.title} Content: ${blog1.content} . Thank you!${"\n"}You must call the ${"`"}getResults${"`"} tool to obtain the correct answer.`;

final string expectedPromptStringForRateBlog10 = string `Evaluate this blogs out of 10.
        Title: ${blog1.title}
        Content: ${blog1.content}

        Title: ${blog1.title}
        Content: ${blog1.content}${"\n"}You must call the ${"`"}getResults${"`"} tool to obtain the correct answer.`;

final string expectedPromptStringForRateBlog11 =
        string `How do you rate this blog content out of 10. Title: ${blog1.title} Content: ${blog1.content} .${"\n"}You must call the ${"`"}getResults${"`"} tool to obtain the correct answer.`;

const expectedPromptStringForBalProgram = string `What's the output of the Ballerina code below?

    ${"```"}ballerina
    import ballerina/io;

    public function main() {
        int x = 10;
        int y = 20;
        io:println(x + y);
    }
    ${"```"}${"\n"}You must call the ${"`"}getResults${"`"} tool to obtain the correct answer.`;

const expectedPromptStringForCountry = string `Which country is known as the pearl of the Indian Ocean?${"\n"}You must call the ${"`"}getResults${"`"} tool to obtain the correct answer.`;

const expectedParameterSchemaStringForRateBlog =
    {"type": "object", "properties": {"result": {"type": "integer"}}};

const expectedParameterSchemaStringForRateBlog7 =
    {"type": "object", "properties": {"result": {"type": ["integer", "null"]}}};

const expectedParameterSchemaStringForRateBlog2 =
    {
    "type": "object",
    "required": ["comment", "rating"],
    "properties": {
        "rating": {"type": "integer", "format": "int64"},
        "comment": {"type": "string"}
    }
};

const expectedParameterSchemaStringForRateBlog3 =
    {"type": "object", "properties": {"result": {"type": "boolean"}}};

const expectedParameterSchemaStringForRateBlog4 =
    {
    "type": "object",
    "properties": {
        "result": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {"name": {"type": "string"}},
                "required": ["name"]
            }
        }
    }
};

const expectedParameterSchemaStringForRateBlog5 =
    {
    "type": "object",
    "properties": {
        "result": {
            "type": "array",
            "items": {
                "required": ["comment", "rating"],
                "type": "object",
                "properties": {
                    "rating": {"type": "integer", "format": "int64"},
                    "comment": {"type": "string"}
                }
            }
        }
    }
};

const expectedParameterSchemaStringForRateBlog6 =
    {
    "type": "object",
    "properties": {
        "result": {
            "type": "array",
            "items": {
                "type": "integer"
            }
        }
    }
};

const expectedParameterSchemaStringForRateBlog8 =
    {
    "type": "object",
    "properties": {
        "result": {
            "type": "array",
            "items": {
                "type": "string"
            }
        }
    }
};

const expectedParameterSchemaStringForRateBlog9 =
    {"type": "object", "properties": {"result": {"type": "string"}}};

const expectedParamterSchemaStringForBalProgram =
    {"type": "object", "properties": {"result": {"type": "integer"}}};

const expectedParamterSchemaStringForCountry =
    {"type": "object", "properties": {"result": {"type": "string"}}};



const expectedParamSchemaForArrayUnionNull =
    {
        "type": "object",
        "properties": {
            "result": {
                "anyOf": [
                    {
                        "type": "array",
                        "items": {
                            "required": [
                                "name"
                            ],
                            "type": "object",
                            "properties": {
                                "name": {
                                    "type": "string"
                                }
                            }
                        }
                    },
                    {
                        "type": "null"
                    }
                ]
            }
        }
    };

const expectedParameterSchemaForArrayUnionRec =
    {
        "type": "object",
        "properties": {
            "result": {
                "anyOf": [
                    {
                        "type": "array",
                        "items": {
                            "required": [
                                "name"
                            ],
                            "type": "object",
                            "properties": {
                                "name": {
                                    "type": "string"
                                }
                            }
                        }
                    },
                    {
                        "required": [
                            "name"
                        ],
                        "type": "object",
                        "properties": {
                            "name": {
                                "type": "string"
                            }
                        }
                    }
                ]
            }
        }
    };

const expectedParameterSchemaForArrayUnionBasicType =
    {
        "type": "object",
        "properties": {
            "result": {
                "anyOf": [
                    {
                        "type": "array",
                        "items": {
                            "required": [
                                "name"
                            ],
                            "type": "object",
                            "properties": {
                                "name": {
                                    "type": "string"
                                }
                            }
                        }
                    },
                    {
                        "type": "string"
                    }
                ]
            }
        }
    };

const expectedParameterSchemaForArrayOnly =
    {
        "type": "object",
        "properties": {
            "result": {
                "type": "array",
                "items": {
                    "required": [
                        "name"
                    ],
                    "type": "object",
                    "properties": {
                        "name": {
                            "type": "string"
                        }
                    }
                }
            }
        }
    };

const expectedParameterSchemaForRecUnionBasicType =
    {
        "type": "object",
        "properties": {
            "result": {
                "anyOf": [
                    {
                        "required": [
                            "name"
                        ],
                        "type": "object",
                        "properties": {
                            "name": {
                                "type": "string"
                            }
                        }
                    },
                    {
                        "type": "string"
                    }
                ]
            }
        }
    };

const expectedParameterSchemaForRecUnionNull =
    {
        "type": "object",
        "properties": {
            "result": {
                "anyOf": [
                    {
                        "required": [
                            "name"
                        ],
                        "type": "object",
                        "properties": {
                            "name": {
                                "type": "string"
                            }
                        }
                    },
                    {
                        "type": "null"
                    }
                ]
            }
        }
    };
