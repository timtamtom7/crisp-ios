# Crisp — App Store Assets

## App Icon Concept

**Visual:** A minimalist microphone icon rendered in the warm gold accent color (#c8a97e), set against a deep black (#0d0d0e) rounded square background. The mic is surrounded by 3 concentric wave rings that evoke both the waveform and the idea of capturing sound. Clean, precise, and immediately legible at all sizes (even 29pt on settings screens).

**Wordmark:** "Crisp" in SF Pro Bold below the icon for larger sizes (1024×1024 App Store icon only).

**SwiftUI Version (for generation):**
```swift
struct AppIconSwiftUI: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 200)
                .fill(Color(hex: "0d0d0e"))

            // Concentric wave rings
            ForEach(0..<3, id: \.self) { ring in
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Color(hex: "c8a97e").opacity(0.6 - Double(ring) * 0.15),
                                     Color(hex: "e8956a").opacity(0.3 - Double(ring) * 0.08)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: CGFloat(50 + ring * 28), height: CGFloat(50 + ring * 28))
            }

            // Mic
            ZStack {
                Circle()
                    .fill(Color(hex: "c8a97e"))
                    .frame(width: 52, height: 52)

                Image(systemName: "mic.fill")
                    .font(.system(size: 22))
                    .foregroundColor(Color(hex: "0d0d0e"))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 200))
    }
}
```

---

## App Name

**Crisp** (already confirmed available)

---

## Tagline

"Just talk."

---

## App Description

### Short Description (170 chars)
The fastest way to capture a thought. One tap, speak your mind, and walk away with a perfectly transcribed note.

### Full Description (4 paragraphs)

**Paragraph 1 — Hook:**
Crisp is the voice note app that gets out of your way. One tap. Speak your mind. Your words appear on screen in real-time, transcribed as you talk. That's it. No typing, no organizing, no friction — just talk and it lives.

**Paragraph 2 — Core Experience:**
Watch your thoughts materialize the moment they leave your mouth. Crisp transcribes in real-time using on-device speech recognition, so your words are captured the instant you say them. The animated waveform responds as you speak, turning every recording into a visual experience. When you're done, your note is already transcribed, saved, and searchable.

**Paragraph 3 — Library & Search:**
Your entire history of voice notes, fully transcribed and instantly searchable. Every word indexed. Remember that idea you had three weeks ago? Just search for it. Play back any recording, copy the text, share it — your library is your second memory.

**Paragraph 4 — Closing:**
Designed for iOS 26 with a deep dark aesthetic, warm gold accents, and the kind of minimal interface that Apple makes look easy. Free to start. Upgrade to Pro or Unlimited when you're ready for more. Crisp — just talk.

---

## Keywords

```
voice, memo, recorder, transcription, speech, dictate, notes,
voice to text, audio recorder, dictation, podcast, meeting,
capture, record, transcribe, voice note, speech to text
```

### Keyword Strategy:
- Primary: voice memo, voice recorder, transcription app
- Secondary: speech to text, voice to text, dictation
- Tertiary: audio notes, capture thoughts, meeting notes
- Competitor-adjacent: Not Voice Memos, Not Otter.ai

### Localized Versions Needed:
- en-US (default)
- Consider: es-ES, fr-FR, de-DE, ja-JP, zh-CN

---

## Subtitle (optional App Store field)

"The fastest way to capture a thought"

---

## Category

**Primary:** Productivity
**Secondary:** Utilities

---

## Age Rating

4+ (All Ages)

---

## Privacy Policy URL

Required before submission. Recommend: `https://crisp.app/privacy`

---

## Terms of Service URL

Optional but recommended: `https://crisp.app/terms`

---

## Support URL

`https://crisp.app/support`

---

## Version Notes for 1.0.0

First release. Features:
- One-tap voice recording with real-time transcription
- Animated waveform visualization
- Searchable transcribed library
- Dark glass iOS 26 aesthetic
- On-device speech recognition (no cloud required)
- Export, share, and copy transcription text
- Settings for language and auto-save
