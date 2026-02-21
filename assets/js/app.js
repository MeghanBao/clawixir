// Phoenix LiveView JS client
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"

// ── Hooks ────────────────────────────────────────────────────────────────

let Hooks = {}

// Auto-scroll messages container to bottom on updates
Hooks.ScrollBottom = {
  mounted() {
    this.scrollToBottom()
    this.observer = new MutationObserver(() => this.scrollToBottom())
    this.observer.observe(this.el, { childList: true, subtree: true })
  },
  updated() {
    this.scrollToBottom()
  },
  destroyed() {
    if (this.observer) this.observer.disconnect()
  },
  scrollToBottom() {
    this.el.scrollTop = this.el.scrollHeight
  }
}

// ── LiveSocket ───────────────────────────────────────────────────────────

let csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  hooks: Hooks,
  params: { _csrf_token: csrfToken },
  longPollFallbackMs: 2500
})

liveSocket.connect()

// Expose for debugging in dev
window.liveSocket = liveSocket
