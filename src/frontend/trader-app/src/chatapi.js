/**
 * API helpers for the chat backend.
 *
 * The Vite proxy (vite.config.ts) rewrites /api → http://localhost:8000
 * during dev so no CORS issues arise and the API key never touches the browser.
 */

// export interface Message {
//   role: "user" | "assistant" | "system";
//   content: string;
// }

// export interface StreamCallbacks {
//   onToken: (token: string) => void;
//   onDone: () => void;
//   onError: (err: string) => void;
// }

/**
 * Send the conversation history to the backend and stream back the assistant's
 * response token by token via Server-Sent Events.
 *
 * Returns an AbortController so the caller can cancel the stream.
 */
export function streamChat(
  messages,
  model,
  callbacks,
) {
  const controller = new AbortController();

  void (async () => {
    let response;
    try {
      response = await fetch("/chat/api/chat", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ messages, model }),
        signal: controller.signal,
      });
    } catch (err) {
      if (err.name !== "AbortError") {
        callbacks.onError(`Network error: ${String(err)}`);
      }
      return;
    }

    if (!response.ok) {
      callbacks.onError(`Server error: ${response.status} ${response.statusText}`);
      return;
    }

    const reader = response.body?.getReader();
    if (!reader) {
      callbacks.onError("No response body");
      return;
    }

    const decoder = new TextDecoder();
    let buffer = "";

    try {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        buffer += decoder.decode(value, { stream: true });

        // Process complete SSE lines
        const lines = buffer.split("\n");
        buffer = lines.pop() ?? ""; // keep the incomplete last fragment

        for (const line of lines) {
          if (!line.startsWith("data: ")) continue;
          const data = line.slice(6).trim();
          if (data === "[DONE]") {
            callbacks.onDone();
            return;
          }
          try {
            const parsed = JSON.parse(data);
            if (parsed.error) {
              callbacks.onError(parsed.error);
              return;
            }
            if (parsed.content) {
              callbacks.onToken(parsed.content);
            }
          } catch {
            // Ignore malformed lines
          }
        }
      }
    } catch (err) {
      if (err.name !== "AbortError") {
        callbacks.onError(`Stream read error: ${String(err)}`);
      }
    } finally {
      reader.releaseLock();
    }

    callbacks.onDone();
  })();

  return controller;
}
