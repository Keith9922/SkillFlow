

``` python
import requests

url = "https://api.siliconflow.cn/v1/chat/completions"

payload = {
    "model": "Qwen/QwQ-32B",
    "messages": [
        {
            "role": "user",
            "content": "What opportunities and challenges will the Chinese large model industry face in 2025?"
        }
    ],
    "stream": False,
    "max_tokens": 4096,
    "enable_thinking": False,
    "thinking_budget": 4096,
    "min_p": 0.05,
    "stop": None,
    "temperature": 0.7,
    "top_p": 0.7,
    "top_k": 50,
    "frequency_penalty": 0.5,
    "n": 1,
    "response_format": { "type": "text" },
    "tools": [
        {
            "type": "function",
            "function": {
                "name": "<string>",
                "description": "<string>",
                "parameters": {},
                "strict": False
            }
        }
    ]
}
headers = {
    "Authorization": "Bearer <token>",
    "Content-Type": "application/json"
}

response = requests.post(url, json=payload, headers=headers)

print(response.text)
```

``` plaintext
{
  "id": "<string>",
  "choices": [
    {
      "message": {
        "role": "assistant",
        "content": "<string>",
        "reasoning_content": "<string>",
        "tool_calls": [
          {
            "id": "<string>",
            "type": "function",
            "function": {
              "name": "<string>",
              "arguments": "<string>"
            }
          }
        ]
      },
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 123,
    "completion_tokens": 123,
    "total_tokens": 123
  },
  "created": 123,
  "model": "<string>",
  "object": "chat.completion"
}
```


下面是 Website Doc 的内容可参考：
VLM
​
model
enum<string>default:Qwen/Qwen2.5-VL-72B-Instructrequired
Corresponding Model Name. To better enhance service quality, we will make periodic changes to the models provided by this service, including but not limited to model on/offlining and adjustments to model service capabilities. We will notify you of such changes through appropriate means such as announcements or message pushes where feasible.

Available options: deepseek-ai/DeepSeek-OCR, Qwen/Qwen3-VL-32B-Instruct, Qwen/Qwen3-VL-32B-Thinking, Qwen/Qwen3-VL-8B-Instruct, Qwen/Qwen3-VL-8B-Thinking, Qwen/Qwen3-VL-30B-A3B-Instruct, Qwen/Qwen3-VL-30B-A3B-Thinking, Qwen/Qwen3-VL-235B-A22B-Instruct, Qwen/Qwen3-VL-235B-A22B-Thinking, Qwen/Qwen3-Omni-30B-A3B-Instruct, Qwen/Qwen3-Omni-30B-A3B-Thinking, Qwen/Qwen3-Omni-30B-A3B-Captioner, zai-org/GLM-4.5V, Pro/THUDM/GLM-4.1V-9B-Thinking, THUDM/GLM-4.1V-9B-Thinking, Qwen/Qwen2.5-VL-32B-Instruct, Qwen/Qwen2.5-VL-72B-Instruct, Qwen/QVQ-72B-Preview, deepseek-ai/deepseek-vl2, Qwen/Qwen2-VL-72B-Instruct, Pro/Qwen/Qwen2.5-VL-7B-Instruct 
Example:
"Qwen/Qwen2.5-VL-72B-Instruct"

​
messages
object[]required
A list of messages comprising the conversation so far.

Required array length: 1 - 10 elements
Hide child attributes

​
messages.role
enum<string>default:userrequired
The role of the messages author. Choice between: system, user, or assistant.

Available options: user, assistant, system 
Example:
"user"

​
messages.content
(Text · object | Image · object | Audio · object | Video · object)[]required
An array of content parts with a defined type, each can be of type text or image_url when passing in images. You can pass multiple images by adding multiple image_url content parts. The Qwen3-Omni series supports video_url and audio_url, enabling the recognition of video and audio content. The Qwen3-VL model also supports video_url, allowing it to recognize video content. Recommend videos and audio within 30 seconds.

Minimum array length: 1
Text
Image
Audio
Video
Show child attributes

​
stream
booleandefault:false
If set, tokens are returned as Server-Sent Events as they are made available. Stream terminates with data: [DONE]

Example:
false

​
max_tokens
integer
The maximum number of tokens to generate. Ensure that input tokens + max_tokens do not exceed the model’s context window. As some services are still being updated, avoid setting max_tokens to the window’s upper bound; reserve ~10k tokens as buffer for input and system overhead. See Models(https://cloud.siliconflow.cn/models) for details.

​
stop

Option 1 · string[]
Up to 4 sequences where the API will stop generating further tokens. The returned text will not contain the stop sequence.

Required array length: 1 - 4 elements
​
temperature
number<float>default:0.7
Determines the degree of randomness in the response.

Example:
0.7

​
top_p
number<float>default:0.7
The top_p (nucleus) parameter is used to dynamically adjust the number of choices for each predicted token based on the cumulative probabilities.

Example:
0.7

​
top_k
number<float>default:50
Example:
50

​
frequency_penalty
number<float>default:0.5
Example:
0.5

​
n
integerdefault:1
Number of generations to return

Example:
1

​
response_format
object
An object specifying the format that the model must output.

Hide child attributes

​
response_format.type
string
The type of the response format.

Example:
"text"

