import * as React from 'react';
import { streamChat } from "../chatapi";

const DEFAULT_MODEL = "elasticsearch";

let nextId = 1;

class ChatBox extends React.Component {
    constructor(props) {
        super(props);
        this.state = {
            messages: [],
            input: "",
            model: DEFAULT_MODEL,
            loading: false,
            error: null,
        };

        this.bottomRef = React.createRef();
        this.abortController = null;
        this.textareaRef = React.createRef();

        this.handleSubmit = this.handleSubmit.bind(this);
        this.handleStop = this.handleStop.bind(this);
        this.handleClear = this.handleClear.bind(this);
        this.handleKeyDown = this.handleKeyDown.bind(this);
    }

    componentDidUpdate(prevProps, prevState) {
        if (prevState.messages !== this.state.messages) {
            this.bottomRef.current?.scrollIntoView({ behavior: "smooth" });
        }
    }

    handleSubmit(e) {
        e.preventDefault();
        const text = this.state.input.trim();
        if (!text || this.state.loading) return;

        this.setState({ error: null });

        const userMsg = { id: nextId++, role: "user", content: text };
        const assistantMsg = {
            id: nextId++,
            role: "assistant",
            content: "",
            streaming: true,
        };

        const history = [...this.state.messages, userMsg].map(({ role, content }) => ({
            role,
            content,
        }));

        this.setState((prev) => ({
            messages: [...prev.messages, userMsg, assistantMsg],
            input: "",
            loading: true,
        }));

        this.abortController = streamChat(history, this.state.model, {
            onToken: (token) => {
                this.setState((prev) => ({
                    messages: prev.messages.map((m) =>
                        m.id === assistantMsg.id ? { ...m, content: m.content + token } : m
                    ),
                }));
            },
            onDone: () => {
                this.setState((prev) => ({
                    messages: prev.messages.map((m) =>
                        m.id === assistantMsg.id ? { ...m, streaming: false } : m
                    ),
                    loading: false,
                }));
            },
            onError: (err) => {
                this.setState((prev) => ({
                    messages: prev.messages.filter((m) => m.id !== assistantMsg.id),
                    error: err,
                    loading: false,
                }));
            },
        });
    }

    handleStop() {
        this.abortController?.abort();
        this.setState((prev) => ({
            messages: prev.messages.map((m) => (m.streaming ? { ...m, streaming: false } : m)),
            loading: false,
        }));
    }

    handleClear() {
        if (this.state.loading) this.handleStop();
        this.setState({ messages: [], error: null });
    }

    handleKeyDown(e) {
        if (e.key === "Enter" && !e.shiftKey) {
            e.preventDefault();
            this.handleSubmit(e);
        }
    }

    render() {
        const { messages, input, model, loading, error } = this.state;

        return (
            <div className="chat-container">

                <div className="messages-area">
                    {messages.length === 0 && (
                        <div className="empty-state">
                            <p>Start a conversation.</p>
                        </div>
                    )}

                    {messages.map((msg) => (
                        <div key={msg.id} className={`message message-${msg.role}`}>
                            <span className="message-role">{msg.role === "user" ? "You" : "Assistant"}</span>
                            <div className="message-content">
                                {msg.content || (msg.streaming ? <span className="cursor">▋</span> : null)}
                                {msg.streaming && msg.content && <span className="cursor">▋</span>}
                            </div>
                        </div>
                    ))}

                    {error && (
                        <div className="error-banner">
                            <strong>Error:</strong> {error}
                        </div>
                    )}

                    <div ref={this.bottomRef} />
                </div>

                <form className="input-area" onSubmit={this.handleSubmit}>
                    <textarea
                        ref={this.textareaRef}
                        value={input}
                        onChange={(e) => this.setState({ input: e.target.value })}
                        onKeyDown={this.handleKeyDown}
                        placeholder="Type a message… (Enter to send, Shift+Enter for newline)"
                        disabled={loading}
                        rows={3}
                    />
                    <div className="input-buttons">
                        {loading ? (
                            <button type="button" className="btn-stop" onClick={this.handleStop}>
                                Stop
                            </button>
                        ) : (
                            <button type="submit" className="btn-send" disabled={!input.trim()}>
                                Send
                            </button>
                        )}
                    </div>
                </form>
            </div>
        );
    }
}

export default ChatBox;
