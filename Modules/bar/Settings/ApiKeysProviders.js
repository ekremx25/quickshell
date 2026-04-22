.pragma library

// Static list of supported AI providers exposed by the API Keys page.
// Each entry seeds the UI form defaults when selected.

var providers = [
    {
        id: "local",
        name: "Local only",
        description: "100% offline — no network, no key needed",
        api_base: "",
        key_prefix: "",
        key_example: "",
        models: [],
        signup_url: "",
        native: true,
        is_local: true
    },
    {
        id: "openai",
        name: "OpenAI",
        description: "ChatGPT API (paid)",
        api_base: "https://api.openai.com/v1",
        key_prefix: "sk-",
        key_example: "sk-...",
        models: ["gpt-4o-mini", "gpt-4o", "gpt-4-turbo", "gpt-3.5-turbo"],
        signup_url: "https://platform.openai.com/api-keys",
        native: true
    },
    {
        id: "groq",
        name: "Groq",
        description: "Free, fast LLaMA inference",
        api_base: "https://api.groq.com/openai/v1",
        key_prefix: "gsk_",
        key_example: "gsk_...",
        models: ["llama-3.3-70b-versatile", "llama-3.1-8b-instant", "mixtral-8x7b-32768"],
        signup_url: "https://console.groq.com/keys",
        native: true
    },
    {
        id: "gemini",
        name: "Google Gemini",
        description: "Free tier (1500 req/day) — via OpenRouter recommended",
        api_base: "https://openrouter.ai/api/v1",
        key_prefix: "sk-or-",
        key_example: "sk-or-...",
        models: ["google/gemini-2.0-flash-exp:free", "google/gemini-flash-1.5"],
        signup_url: "https://openrouter.ai/keys",
        native: false,
        via: "OpenRouter"
    },
    {
        id: "claude",
        name: "Anthropic Claude",
        description: "Via OpenRouter (native API in Phase 2)",
        api_base: "https://openrouter.ai/api/v1",
        key_prefix: "sk-or-",
        key_example: "sk-or-...",
        models: ["anthropic/claude-3-5-haiku", "anthropic/claude-3-5-sonnet"],
        signup_url: "https://openrouter.ai/keys",
        native: false,
        via: "OpenRouter"
    },
    {
        id: "ollama",
        name: "Ollama",
        description: "100% local — private, free, offline",
        api_base: "http://localhost:11434/v1",
        key_prefix: "",
        key_example: "(any value, not used)",
        models: ["llama3.2:3b", "llama3.1:8b", "phi3:mini", "qwen2.5:3b", "mistral:7b"],
        signup_url: "https://ollama.com",
        native: true
    },
    {
        id: "openrouter",
        name: "OpenRouter",
        description: "Gateway to 200+ models (mix of free + paid)",
        api_base: "https://openrouter.ai/api/v1",
        key_prefix: "sk-or-",
        key_example: "sk-or-...",
        models: ["meta-llama/llama-3.1-8b-instruct:free", "google/gemini-2.0-flash-exp:free", "anthropic/claude-3-5-haiku", "openai/gpt-4o-mini"],
        signup_url: "https://openrouter.ai/keys",
        native: true
    },
    {
        id: "custom",
        name: "Custom",
        description: "Any OpenAI-compatible endpoint",
        api_base: "",
        key_prefix: "",
        key_example: "your key here",
        models: [],
        signup_url: "",
        native: true
    }
];

function byId(id) {
    for (var i = 0; i < providers.length; i++) {
        if (providers[i].id === id) return providers[i];
    }
    return providers[0];
}
