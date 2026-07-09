In Emacs, "elision" is the general mechanism for hiding chunks of buffer text while still displaying a placeholder (usually "...") where the hidden text used to be. Markdown mode's section-folding (and org-mode's, and outline-mode's) all reuse this same low-level machinery rather than each inventing their own.

The core pieces:

Invisible text isn't deleted — it's marked. Emacs lets you attach an `invisible` property (via a text property or an overlay) to a stretch of text. The display engine then decides whether to actually render that text based on `buffer-invisibility-spec`, a buffer-local variable listing which property values should be hidden.

Each entry in `buffer-invisibility-spec` can be just a symbol (hide the text, no indicator) or a cons cell like `(SYMBOL . t)` (hide the text and show an ellipsis in its place). This is what gives you the "..." after a folded heading instead of the heading just silently swallowing everything below it.

Markdown mode's folding (`markdown-cycle`, bound to TAB, mimicking org-mode) works by treating `#`, `##`, `###` etc. as outline levels, essentially the same way `outline-mode` treats stars or indentation. When you fold a section, markdown-mode creates an overlay over the body text with `invisible` set to a symbol like `outline`, and since `(outline . t)` is in the invisibility spec, that overlay's text collapses to an ellipsis.

Because this is purely a display-layer trick, the hidden text is still fully present in the buffer. Searches, `query-replace`, and programmatic buffer edits still see it (isearch can optionally auto-reveal folded regions it matches inside). Undo, saving, and everything else is unaffected — only what you see on screen changes.

This is different from `hs-minor-mode` (hideshow), which does similar overlay-based hiding but is driven by syntactic blocks (braces, indentation) rather than heading levels, and different again from the older `selective-display` variable, which hides lines based on indentation column and predates the overlay/invisibility-spec system — it's cruder and doesn't support custom ellipsis behavior.

---
For hand-placed layer markers, `outline-minor-mode` is the right tool — it's exactly what you're describing: mark comment lines as headings at different depths, then fold/unfold by depth.

Enable it for code buffers and set a regexp defining what counts as a heading and how depth is computed:

```elisp
(add-hook 'prog-mode-hook #'outline-minor-mode)
(setq outline-minor-mode-cycle t)  ; Emacs 28+: TAB cycles fold state like org-mode
```

Then per-mode (or globally with a mode-agnostic pattern), define your marker convention using the language's comment leader plus a repeated character for depth, e.g. for elisp/lisp-family comments:

```elisp
(setq-local outline-regexp ";;;+")
```

so you write:

```elisp
;;; Layer 1
;;;; Layer 2
;;;;; Layer 3
```

and the number of trailing semicolons is the depth (outline computes `outline-level` from the match length by default, so this "just works" without a custom function). For `//`-comment languages you'd use something like `"// \\*+"` with headings like `// * Layer 1`, `// ** Layer 2`.

Once set up, the commands that matter:
`outline-hide-sublevels N` — elide everything below depth N (this is literally "collapse to layer N," the operation you're after). `outline-cycle` (or TAB with `outline-minor-mode-cycle` on) — cycle a single heading through show-all/show-children/hide at point. `outline-hide-body` / `outline-show-all` — collapse or reveal everything.

Two things worth knowing before you commit to this:

`outshine` (a package, not built in) layers nicer org-style TAB-cycling and `M-RET` heading-insertion on top of outline-minor-mode, and it auto-derives a sensible `outline-regexp` from each major mode's comment syntax, so you often don't need to hand-set the regexp per language.

If your "layers" actually correspond to syntactic nesting (functions, blocks, braces) rather than manually placed comments, `hs-minor-mode` (hideshow) folds by code structure instead of markup — no comments to insert, but you don't get arbitrary custom layer names either. Outline is for markup-driven layers; hideshow is for structure-driven ones. They can coexist in the same buffer if you want both.

---

I want
```
defproc container-handler {
  .handle incoming mevent for a composite part (a "container") by punting the mevent to appropriate children via the container's wiring list, then keep stepping children until they all go quiescent {
    ..%with-container %self {
      ...punt-to-children {
       # tos is a mev
       <mev
           >(mev %top-container %top-container) @deliver-atomically
         }
      ...step-until-quiescence {
      %with-cause mev {
         %while >%top-container @any-child-ready {
           >%top-container @step-ready-children
         }
       }
      }
    }
}
```

to elide something like:

```
defproc container-handler {
  .handle incoming mevent for a composite part (a "container") by punting the mevent to appropriate children via the container's wiring list, then keep stepping children until they all go quiescent {
  ...
}
```

```
then to
```
defproc container-handler {
  .handle incoming mevent for a composite part (a "container") by punting the mevent to appropriate children via the container's wiring list, then keep stepping children until they all go quiescent {
    ..%with-container %self {
       ...
    }
}
```
then to
```
defproc container-handler {
  .handle incoming mevent for a composite part (a "container") by punting the mevent to appropriate children via the container's wiring list, then keep stepping children until they all go quiescent {
    ..%with-container %self {
      ...punt-to-children { ... }
      ...step-until-quiescence { ... }
    }
}
```

---

Your dot-count prefixes (`.`, `..`, `...`) already are an outline hierarchy — you just need to tell `outline-minor-mode` to read them as levels. Set this up and `outline-hide-sublevels N` gives you exactly your three stages.

```elisp
(defun my-dsl-outline-level ()
  (save-excursion
    (skip-chars-forward " \t")
    (let ((start (point)))
      (skip-chars-forward ".")
      (- (point) start))))          ; level = number of leading dots

(defun my-dsl-outline-setup ()
  (setq-local outline-regexp "[ \t]*\\.+")
  (setq-local outline-level #'my-dsl-outline-level)
  (outline-minor-mode 1))

(add-hook 'YOUR-MODE-hook #'my-dsl-outline-setup)  ; whatever mode edits this DSL
```

Then:

`(outline-hide-sublevels 1)` → only `.handle ... {` visible, everything below elided — your first snippet.
`(outline-hide-sublevels 2)` → adds `..%with-container %self {`, still folds its contents — your second snippet.
`(outline-hide-sublevels 3)` → adds both `...punt-to-children {` and `...step-until-quiescence {` headings, folding just their bodies — your third snippet.

Bind these to keys (`1`/`2`/`3` on some prefix) if you want a quick drill-down. For poking at one branch at a time instead of the whole buffer, put point on a heading and use `outline-cycle` (TAB, with `(setq outline-minor-mode-cycle t)` set globally) — it steps that single heading through folded → children-shown → fully-shown without touching its siblings.

One caveat: outline elision is heading-based, not brace-matching. A stray `}` that closes a dotted block but isn't itself a dotted line gets swallowed into that block's body until you expand it — so the trailing `}` in your stage-1/2 examples is really the tail end of the elided `.handle`/`..%with-container` body, not something outline is preserving specially. That's consistent with what you sketched, just worth knowing it's not doing brace-matching under the hood — it doesn't need to, since your dots already encode the depth outline cares about.

---

I use javascript-mode

---
Careful with hooking this to `js-mode-hook` (javascript-mode) globally — real JS commonly starts continuation lines with a single dot (method chaining: `.then(...)`, `.map(...)`), which would get misread as level-1 headings everywhere and make ordinary JS unreadable.

Two ways to scope it safely:

**On-demand (simplest):** don't hook it at all, just make it a command you invoke in the buffers that are actually your DSL.

```elisp
(defun my-dsl-outline-level ()
  (save-excursion
    (skip-chars-forward " \t")
    (let ((start (point)))
      (skip-chars-forward ".")
      (- (point) start))))

(defun my-dsl-outline-mode ()
  (interactive)
  (setq-local outline-regexp "[ \t]*\\.+")
  (setq-local outline-level #'my-dsl-outline-level)
  (outline-minor-mode 1))
```

Run `M-x my-dsl-outline-mode` in a DSL buffer; leave other JS buffers untouched.

**Scoped by directory (persistent):** if these DSL files live in their own project/folder, drop a `.dir-locals.el` at the root so it applies automatically only there, not to js-mode generally:

```elisp
((javascript-mode . ((eval . (my-dsl-outline-mode)))))
```

Emacs will ask once to confirm the eval is safe for that directory (normal for `.dir-locals.el`).

If these files are common enough to want a distinct identity (syntax highlighting tweaks later, etc.), the cleaner long-term move is a derived mode — `(define-derived-mode my-dsl-mode javascript-mode "MyDSL" ...)` — mapped to a specific extension via `auto-mode-alist`, with the outline setup in its own hook. That keeps it fully separate from plain `.js` editing. Worth doing if you'll be extending this beyond folding; overkill if it's just for you and a handful of files.

---

Just swap the character in the regexp and the `skip-chars-forward` calls. `%` isn't a regex metacharacter (unlike `.`), so it doesn't need escaping — actually simpler than before.

```elisp
(defun my-dsl-outline-level ()
  (save-excursion
    (skip-chars-forward " \t")
    (let ((start (point)))
      (skip-chars-forward "%")        ; was "."
      (- (point) start))))

(defun my-dsl-outline-mode ()
  (interactive)
  (setq-local outline-regexp "[ \t]*%+")   ; was "[ \t]*\\.+"
  (setq-local outline-level #'my-dsl-outline-level)
  (outline-minor-mode 1))
```

One thing to watch: your DSL already uses a leading `%` as a sigil for identifiers (`%self`, `%top-container`, `%with-cause`). Since `outline-regexp` only matches at the start of a line (not mid-line), a line like `%while >%top-container @any-child-ready {` would itself be read as a level-1 heading, because it happens to start with `%`. With `.` as the marker this didn't happen since ordinary code never starts a line with a dot in your DSL. So switching to `%` may pick up more headings than you intend, wherever a `%name` construct happens to sit at the start of a line rather than only your deliberate `..`/`...` markers. Worth checking your actual files for that before committing to it — if it's a problem, picking a marker character that doesn't otherwise appear at line-start (or requiring a space after the run of `%`s in the regexp, e.g. `"[ \t]*%+ "`) would disambiguate.

---

Yes — Emacs can render inline SVG directly in a buffer, as long as it was built with SVG support. Check first:

```elisp
(image-type-available-p 'svg)
```

If that's `t`, you have two ways to get an SVG on screen inline, not as a separate file/window:

**From a file or raw SVG string:**
```elisp
(insert-image (create-image "/path/to/file.svg" 'svg))
;; or from an SVG string you built yourself:
(insert-image (create-image svg-string 'svg t))
```

**Built programmatically with `svg.el`** (built into Emacs, useful if you want to generate a diagram from your DSL's structure rather than hand-author files):
```elisp
(require 'svg)
(let ((svg (svg-create 100 40)))
  (svg-rectangle svg 0 0 100 40 :fill "none" :stroke "black")
  (svg-text svg "container" :x 10 :y 25)
  (insert-image (svg-image svg)))
```

Both produce an image object that goes wherever point is — no separate buffer or window, no `<img>` markup, just a Lisp image spec.

For tying it to the folding work: images don't need to replace the "..." — the elision (`invisible` property) and image display (`display` property) are independent overlay properties. You could put a small SVG (say, a wiring diagram of the container's children) on an overlay positioned right at a heading line, so it stays visible whether that heading's body is folded or expanded — a permanent annotation rather than something that appears only when collapsed. If instead you want the image to *replace* the elided text (shown only while folded), put the `display` property directly on the same overlay that has `invisible`/ellipsis — when Emacs hides invisible text it still respects a `display` property on that overlay's region, so the image shows in place of the ellipsis.

One caveat: this is real image rendering, not markdown-style `![]()` syntax — there's no markup convention for it built into outline or your DSL; you'd write Lisp (in a hook, or an interactive command) that scans for wherever you want an image and applies the overlay yourself.

---

I want to have something like
```
      ⋅⋅⋅ punt mevent down to children (which may cause internal events) ![punt](tpbp-punt.drawio.svg)
           deliver-atomically (mev, top_container (), top_container ())
```
with the image expanded at the ![punt](...) point. I don't care which syntax I need to use to include the image.

---
That `![alt](path)` syntax has no special meaning to Emacs on its own — you need a small scanner that finds it and swaps in the image via the same overlay `display` mechanism from before. Something like:

```elisp
(defun my-dsl-display-images ()
  "Render ![alt](path.svg) links in the buffer as inline images."
  (interactive)
  (my-dsl-remove-images)
  (save-excursion
    (goto-char (point-min))
    (while (re-search-forward "!\\[\\([^]]*\\)\\](\\([^)]+\\))" nil t)
      (let* ((path (match-string 2))
             (full-path (expand-file-name
                         path (file-name-directory (or buffer-file-name default-directory))))
             (beg (match-beginning 0))
             (end (match-end 0)))
        (when (and (file-exists-p full-path)
                   (image-type-available-p 'svg))
          (let* ((img (create-image full-path 'svg nil :max-width 400))
                 (ov (make-overlay beg end)))
            (overlay-put ov 'my-dsl-image t)
            (overlay-put ov 'display img)))))))

(defun my-dsl-remove-images ()
  "Undo `my-dsl-display-images'."
  (interactive)
  (remove-overlays (point-min) (point-max) 'my-dsl-image t))
```

Run `M-x my-dsl-display-images` and each `![punt](tpbp-punt.drawio.svg)` gets replaced in-place by the rendered SVG, right where the markdown text was — the rest of the line (`punt mevent down to children ...`) stays untouched as ordinary text. `my-dsl-remove-images` flips it back to raw text for editing.

Notes:

Path resolution is relative to the buffer's file directory — adjust `file-name-directory` there if your `.drawio.svg` files live somewhere else relative to the source.

`:max-width 400` keeps large drawio exports from taking over the buffer; drop it or tune it to taste (Emacs 27+ required for that image property).

This composes with your outline folding automatically: the image-display overlay is independent of the outline elision overlay. If the link sits inside a region currently folded by outline, it stays hidden along with everything else; when you expand that heading, the image is already rendered and just becomes visible.

You may want to auto-run `my-dsl-display-images` after loading a file or after `outline-cycle`/`outline-hide-sublevels`, since folding/unfolding doesn't itself trigger a rescan — only new text needs a fresh scan; already-placed overlays survive folding just fine.

---

That's Emacs's image cache — it keys cached bitmaps by the image spec (file path + type) and doesn't watch the file on disk, so editing the `.svg` in place doesn't invalidate what's already rendered. The fix is `image-flush`, which is built for exactly this: it checks whether the file's mtime changed since it was cached and reloads if so.

Fold it into your refresh function:

```elisp
(defun my-dsl-display-images ()
  "Render ![alt](path.svg) links in the buffer as inline images."
  (interactive)
  (my-dsl-remove-images)
  (save-excursion
    (goto-char (point-min))
    (while (re-search-forward "!\\[\\([^]]*\\)\\](\\([^)]+\\))" nil t)
      (let* ((path (match-string 2))
             (full-path (expand-file-name
                         path (file-name-directory (or buffer-file-name default-directory))))
             (beg (match-beginning 0))
             (end (match-end 0)))
        (when (and (file-exists-p full-path)
                   (image-type-available-p 'svg))
          (let* ((img (create-image full-path 'svg nil :max-width 400))
                 (ov (make-overlay beg end)))
            (image-flush img)          ; <- force reload if file changed on disk
            (overlay-put ov 'my-dsl-image t)
            (overlay-put ov 'display img)))))))
```

If you're regenerating several files at once and want a bigger hammer, `(clear-image-cache)` with no args flushes everything Emacs has cached, not just this buffer's images — fine to call before `my-dsl-display-images` if per-image flushing feels finicky:

```elisp
(defun my-dsl-refresh-images ()
  (interactive)
  (clear-image-cache)
  (my-dsl-display-images))
```

Bind that to a key you hit after regenerating a diagram (e.g. after drawio re-exports the svg) and it'll always show the current file.

---

I want to be able to elide all lines beginning with ⋅

---

Same overlay-based invisibility mechanism as before, just applied per-line instead of per-outline-level, with a simple regex match rather than a heading hierarchy:

```elisp
(defvar my-dsl-dot-line-regexp "^[ \t]*⋅")

(defun my-dsl-hide-dot-lines ()
  "Hide all lines beginning with ⋅."
  (interactive)
  (add-to-invisibility-spec 'my-dsl-dot-line)   ; no ellipsis; lines just vanish
  (save-excursion
    (goto-char (point-min))
    (while (re-search-forward my-dsl-dot-line-regexp nil t)
      (let* ((beg (line-beginning-position))
             (end (min (point-max) (1+ (line-end-position))))  ; swallow the newline too
             (ov (make-overlay beg end)))
        (overlay-put ov 'my-dsl-dot-line t)
        (overlay-put ov 'invisible 'my-dsl-dot-line)))))

(defun my-dsl-show-dot-lines ()
  "Undo `my-dsl-hide-dot-lines'."
  (interactive)
  (remove-from-invisibility-spec 'my-dsl-dot-line)
  (remove-overlays (point-min) (point-max) 'my-dsl-dot-line t))

(defun my-dsl-toggle-dot-lines ()
  (interactive)
  (if (memq 'my-dsl-dot-line buffer-invisibility-spec)
      (my-dsl-show-dot-lines)
    (my-dsl-hide-dot-lines)))
```

Bind `my-dsl-toggle-dot-lines` to a key. Each matching line's overlay spans through its trailing newline, so hidden lines take zero vertical space rather than leaving a gap — the whole line disappears, not just its text.

If you'd rather see a marker where lines were hidden (instead of them silently vanishing), use `(add-to-invisibility-spec '(my-dsl-dot-line . t))` — then Emacs shows "..." wherever text tagged with that symbol is hidden. With one overlay per line that means one "..." per hidden line, which gets noisy if you're hiding many in a row; the no-ellipsis version above is usually cleaner for this case.

This is independent of the outline-based folding — it's a flat rule (any `⋅`-line, regardless of nesting) rather than a hierarchy, so it composes fine alongside `outline-minor-mode`: a line can be both inside a folded outline section and separately tagged invisible by this rule: same idea (invisible property + `buffer-invisibility-spec`), just two different symbols doing two different jobs. Re-run `my-dsl-hide-dot-lines` after editing to pick up new `⋅` lines, same as the image scan.

---

Given a command, I want to pass the whole contents of the buffer though to T2T by shelling out to a filter process, then display the result, without losing information in the buffer, so that the next time the full contents of the buffer is sent to another filter.

In essence, I want to keep all information in the buffer, then apply different filters to it for diaplying certain aspects and eliding other aspects.

---

This is the same non-destructive-view idea as the image/elision work, just driven by an external process instead of in-buffer markup: the real buffer text is your single source of truth, and each "filter" is a disposable overlay on top of it, never a mutation of it.

```elisp
(defvar-local t2t-view-overlay nil
  "Overlay currently showing a filtered view of the buffer, if any.")

(defun t2t-run-filter (command)
  "Pipe the whole buffer through shell COMMAND and display the result
in place of the buffer's own text, without touching that text."
  (interactive "sT2T filter command: ")
  (let* ((source (buffer-string))
         (output (with-temp-buffer
                   (insert source)
                   (shell-command-on-region (point-min) (point-max) command t t)
                   (buffer-string))))
    (when t2t-view-overlay (delete-overlay t2t-view-overlay))
    (setq t2t-view-overlay (make-overlay (point-min) (point-max) nil nil t))
    (overlay-put t2t-view-overlay 'display output)
    (setq buffer-read-only t)))   ; guard: no typing into hidden real text

(defun t2t-show-raw ()
  "Drop the filtered view; go back to editing the real buffer."
  (interactive)
  (when t2t-view-overlay
    (delete-overlay t2t-view-overlay)
    (setq t2t-view-overlay nil))
  (setq buffer-read-only nil))
```

`t2t-run-filter` always reads `(buffer-string)` fresh — the actual editable text — feeds it to your filter as stdin via a throwaway temp buffer, and puts the resulting output on one overlay spanning the whole buffer with a `display` property. That overlay makes Emacs render the filter's output instead of the real text, but the real text is sitting untouched underneath. Run `t2t-run-filter` again with a different command and it starts again from the same pristine source — nothing was ever lost, because nothing was ever edited, only displayed differently. `t2t-show-raw` just deletes the overlay to get your editable text back.

The read-only toggle matters: while the display overlay is active, point still lives at real buffer positions even though what's on screen is the filter's output, so typing would insert into text you can't see. Locking the buffer while "viewing" and unlocking via `t2t-show-raw` before editing keeps that from becoming confusing. If you want to type while comparing against a filtered view instead of toggling back and forth, the more standard alternative is to send the output to a second buffer (`shell-command-on-region` with `replace` nil, default output buffer) and view it in another window — less elegant for your "everything is a view over one buffer" model, but avoids the read-only dance since the source buffer is simply never touched by the overlay trick at all.

Both approaches compose fine with the outline folding and `⋅`-line hiding you already have — those act on the real text's invisibility, this acts on display substitution for the same real text, and none of the three ever mutates the buffer's actual contents.

---

I want the text that is visible to be editable. I want to shell-out to a filter, return some text that is guaranteed to be a subset of what was sent to the filter, then display the text and allow editing it. The filter can add editability marks for each visible line, if that's necessary.


---

Since the filter's output is guaranteed to be a literal subset of the input lines, you don't need `display` substitution at all — you can go back to the `invisible` overlay technique from your `⋅`-line hiding, which keeps everything as real, directly editable buffer text. The trick is correlating each surviving output line back to its exact source line, so the filter should tag each kept line with its original line number.

Have the filter emit `LINENO<TAB>original line text` for every line it keeps, dropping everything else:

```elisp
(defvar-local t2t-hidden-symbol 't2t-hidden)

(defun t2t-run-line-filter (command)
  "Run COMMAND on the whole buffer. COMMAND must echo back a subset
of the buffer's lines verbatim, each prefixed with its 1-based
source line number and a TAB (e.g. \"42\\tsome original line\").
Lines it omits are elided but remain in the buffer, untouched;
lines it keeps stay exactly as-is and fully editable."
  (interactive "sT2T line filter command: ")
  (let* ((source (buffer-string))
         (output (with-temp-buffer
                   (insert source)
                   (shell-command-on-region (point-min) (point-max) command t t)
                   (buffer-string)))
         (keep (make-hash-table :test 'eql)))
    (dolist (line (split-string output "\n" t))
      (when (string-match "\\`\\([0-9]+\\)\t" line)
        (puthash (string-to-number (match-string 1 line)) t keep)))
    (add-to-invisibility-spec t2t-hidden-symbol)  ; no ellipsis; add '(t2t-hidden . t) for one
    (remove-overlays (point-min) (point-max) 't2t-view t)
    (save-excursion
      (goto-char (point-min))
      (let ((lineno 1) (hide-start nil))
        (while (not (eobp))
          (if (gethash lineno keep)
              (when hide-start
                (t2t--hide hide-start (line-beginning-position))
                (setq hide-start nil))
            (unless hide-start (setq hide-start (line-beginning-position))))
          (forward-line 1)
          (setq lineno (1+ lineno)))
        (when hide-start (t2t--hide hide-start (point-max)))))))

(defun t2t--hide (beg end)
  (let ((ov (make-overlay beg end)))
    (overlay-put ov 't2t-view t)
    (overlay-put ov 'invisible t2t-hidden-symbol)))

(defun t2t-show-all-lines ()
  "Reveal every line again."
  (interactive)
  (remove-overlays (point-min) (point-max) 't2t-view t))
```

This gives you exactly what you asked for: visible text is the real buffer text, not a rendered copy, so you edit it with ordinary Emacs commands and it's a normal edit to the one true buffer. Hidden lines are also real text, just invisible — nothing was ever deleted or copied elsewhere, so undo, search, and further edits all behave normally. Because `t2t-run-line-filter` always starts from a fresh `(buffer-string)`, any edits you've made to the visible lines are automatically what gets sent the next time you invoke a filter — there's no stale-copy problem to manage.

The line-number tag is the "editability mark" you mentioned: it's what lets the correlation be exact even if two kept lines happen to have identical text, since you're matching by position, not by content diffing. If your filter would rather use a different marker style (a leading comment, a sentinel character, whatever's easiest to emit in T2T's implementation language), just adjust the regexp in the `dolist` loop — the rest of the mechanism doesn't care how the line number gets encoded, only that it can be pulled out per output line.

One consequence worth knowing: if you edit a visible line so its line count changes (add/remove a newline), the buffer's line numbers shift before you run the next filter — but since each filter run recomputes everything fresh from current `buffer-string` and current line positions, that's not a bug, it's just always operating on the live, current numbering.

---

explain how wikilinks format differs from markdown image format , e.g. [[abc.svg]] vs. ![abc](./abc.svg)

---

The two forms come from different traditions and encode different information.

`![abc](./abc.svg)` is markdown's (CommonMark's) standard image syntax. The leading `!` is the sole signal that this is an embed rather than a link — drop it and `[abc](./abc.svg)` is just a hyperlink instead. The bracketed part is alt text (shown if the image fails to load, read by screen readers), not a display label the way it might look; it's semantically distinct from the path, which sits in parens as an explicit, literal path — relative to the current file, absolute, or a URL, resolved exactly as written, nothing fuzzier.

`[[abc.svg]]` is wikilink syntax, from MediaWiki and adopted with variations by Obsidian, Roam, Logseq, Foam, TiddlyWiki, etc. Double brackets just mean "link to this target" — by itself it says nothing about whether the target is an image versus a note versus a page title. Whether it embeds inline or acts as a clickable link is not specified by the syntax itself; it's decided by whatever tool is rendering it. Some tools (Obsidian) borrow markdown's convention and require a leading `!` for an actual embed — `![[abc.svg]]` — with bare `[[abc.svg]]` producing just a link. Others infer embedding purely from the file extension. Plain MediaWiki instead uses a namespace prefix (`[[File:abc.svg]]`) to mark it as media rather than a page link. So `[[abc.svg]]` alone is genuinely ambiguous without knowing which flavor of wikilink you're targeting.

Wikilinks also usually resolve targets by name against an index of the whole wiki/vault, not by relative filesystem path — `abc.svg` gets found wherever it lives, rather than being read literally like `./abc.svg`. And the optional pipe syntax (`[[abc.svg|caption]]`, or MediaWiki's richer `[[File:abc.svg|thumb|200px|caption]]`) is a tool-specific mini-language for captions/sizing, with no standard shared across implementations — whereas markdown's image syntax means exactly one thing everywhere it's valid CommonMark.

Practically, for your buffer scanner: if you wanted to also recognize `[[abc.svg]]`, you'd need to pick one of those disambiguation strategies yourself, since the bracket syntax alone won't tell you "treat this as an image" the way the markdown `!` does. Cheapest option is probably inferring embed-vs-link from the file extension (if it ends in `.svg`/`.png`/etc., treat it as an image target) rather than requiring a second marker character.

---

back to `my-dsl-display-images`. I want to parameterize :max-width so that it can appear in every ![..](...) markup, something like `![punt][400](tpbp-punt.drawio.svg)` (when the second [400] is missing, it means to use the default size)

---

Add a second optional `[N]` bracket group before the path, matching only digits, using a shy group so it's optional as a whole:

```elisp
(defvar my-dsl-default-image-width 400
  "Default :max-width used for ![alt](path) links with no [width] given.")

(defun my-dsl-display-images ()
  "Render ![alt][width](path.svg) as inline images.
[width] is optional; omitted, `my-dsl-default-image-width' is used."
  (interactive)
  (my-dsl-remove-images)
  (save-excursion
    (goto-char (point-min))
    (while (re-search-forward
            "!\\[\\([^]]*\\)\\]\\(?:\\[\\([0-9]+\\)\\]\\)?(\\([^)]+\\))"
            nil t)
      (let* ((width (if (match-string 2)
                         (string-to-number (match-string 2))
                       my-dsl-default-image-width))
             (path (match-string 3))
             (full-path (expand-file-name
                         path (file-name-directory (or buffer-file-name default-directory))))
             (beg (match-beginning 0))
             (end (match-end 0)))
        (when (and (file-exists-p full-path)
                   (image-type-available-p 'svg))
          (let* ((img (create-image full-path 'svg nil :max-width width))
                 (ov (make-overlay beg end)))
            (image-flush img)
            (overlay-put ov 'my-dsl-image t)
            (overlay-put ov 'display img)))))))
```

What changed in the regex: `\\(?:\\[\\([0-9]+\\)\\]\\)?` is a shy (non-capturing) wrapper making the whole `[400]` chunk optional, while the digits inside still form a real capture group. That shifts the group numbering — alt text is still group 1, but width is now group 2 and path moves to group 3 (previously path was group 2). `(match-string 2)` comes back as `nil` when `[width]` is absent, which is exactly the "missing means default" check you wanted; when present, it's converted from string to number and passed straight through as `:max-width`.

`my-dsl-remove-images` and `image-flush` usage are unchanged from before — this only touches the parsing and the `:max-width` value fed to `create-image`.

--

to be noted and not acted upon at this moment: I am replacing `my-dsl-` with `st-`

---

what code do I need to add to emacs' `init.el` to bind the key command-1 (meta-1) to execute `(outline-hide-sublevels 1)`

---

```elisp
(defun st-outline-hide-level-1 ()
  "Fold the buffer to outline level 1."
  (interactive)
  (outline-hide-sublevels 1))

(global-set-key (kbd "M-1") #'st-outline-hide-level-1)
```

`"M-1"` is Meta-1 in Emacs' kbd notation — on your setup, where Command already acts as Meta (`mac-command-modifier` set to `'meta`), that's Command-1 as you want it.

One thing to flag: `M-1` is normally bound globally to `digit-argument`, part of how `M-1`, `M-2`, etc. let you type a numeric prefix argument (e.g. `M-5 M-x foo`). Rebinding it globally means you lose that shortcut everywhere, not just in outline buffers. If you'd rather keep `M-1` free for prefix args elsewhere and only fold outlines with it in relevant buffers, bind it in `outline-minor-mode-map` instead:

```elisp
(with-eval-after-load 'outline
  (define-key outline-minor-mode-map (kbd "M-1") #'st-outline-hide-level-1))
```

That only takes effect in buffers where `outline-minor-mode` is on, leaving `M-1` alone everywhere else.

---
can I write the following binding more concisely?
```
(defun st-outline-hide-level-1 ()
  "Fold the buffer to outline level 1."
  (interactive)
  (outline-hide-sublevels 1))
(with-eval-after-load 'outline
  (define-key outline-minor-mode-map (kbd "M-1") #'st-outline-hide-level-1))
```
---

```elisp
(with-eval-after-load 'outline
  (define-key outline-minor-mode-map (kbd "M-1")
    (lambda () (interactive) (outline-hide-sublevels 1))))
```

Drops the separate `defun` — the lambda goes directly where the function symbol was. Trade-off: an anonymous lambda doesn't get a name, so it won't show up in `M-x`, `apropos`, or carry a docstring the way `st-outline-hide-level-1` did. Fine for a pure keybinding-only command; worth keeping the named `defun` if you ever want to invoke it by name or document it.

---
how do I display the code (the undotted `deliver-atomically ...` and `while ...`) in the following?
```
⋅ defproc container-handler (self) {
  ⋅⋅ handle incoming mevent for a composite part (a "container")
      ⋅⋅⋅ punt incoming mevent down to each child connected to the input
      ⋅⋅⋅ then cause each child to step once and react to the mevent
      ⋅⋅⋅ this might cause the children to generate more mevents internal to the container
      ⋅⋅⋅ so, loop and recursively step all children until internal mevents have died down (quiescence)
      ⋅⋅⋅ i.e. such that all internal reactions to this single incoming mevent have quiesced
      ⋅⋅⋅ ![punt][200](tpbp-punt.drawio.svg)
      ⋅⋅⋅⋅. $with-container (self)
           deliver-atomically (mev, top_container (), top_container ())
      ⋅⋅⋅ step until quiescense
      ⋅⋅⋅ ![step][200](tpbp-step.drawio.svg)
      	  ⋅⋅⋅⋅ $with-cause (mev)
	     while any-child-ready (@top_container) {
	       step-ready-children (@top_container))
	     }
	   }
}

```

---

The reason the code stays hidden even once you've folded down to the right heading depth: `outline-hide-sublevels N` always hides the *body* text of every visible heading, no matter how deep N goes — it only ever reveals heading lines, never the text sitting under them. Since your `deliver-atomically (...)` and `while (...) {...}` lines aren't headings themselves (no leading `⋅`), they're just body text attached to the `⋅⋅⋅⋅` heading above them, so they're hidden right along with everything else at that level.

To reveal them, use `outline-show-entry` with point on (or inside) that `⋅⋅⋅⋅` heading — it shows the body text immediately following a heading, up to the next heading of equal-or-shallower depth, without touching anything deeper elsewhere in the buffer:

```elisp
M-x outline-show-entry
```

Since these `⋅⋅⋅⋅` headings have no further sub-headings under them (the code is the last thing there), `outline-show-entry` is exactly enough — there's nothing "deeper" left to accidentally expose.

If you're using `outline-cycle`/TAB at point on that heading, it should get you there too, cycling through folded → children-shown → fully-shown; since there are no child headings to show, one or two presses lands on "fully shown," which reveals the code.

If you want a dedicated key for this (paired with your `M-1`/`M-2`/`M-3` depth bindings), wrap it:

```elisp
(defun st-outline-reveal-code ()
  "Show the body text (code) under the heading at point."
  (interactive)
  (outline-show-entry))

(with-eval-after-load 'outline
  (define-key outline-minor-mode-map (kbd "M-0") #'st-outline-reveal-code))
```

That gives you `M-1`/`M-2`/`M-3` to pick how much annotation hierarchy to show, and `M-0` to drop into the actual code wherever point currently sits.

---

how do I hide all lines that are marked as architectural comments? An architectural comment begins with leading spaces and `⋅`

---

```elisp
(defvar st-arch-comment-regexp "^[ \t]*⋅"
  "Matches an architectural-comment line: leading whitespace then ⋅.")

(defvar st-arch-comment-symbol 'st-arch-comment)

(defun st-hide-arch-comments ()
  "Hide all architectural-comment lines (leading ⋅), keeping only code visible."
  (interactive)
  (add-to-invisibility-spec st-arch-comment-symbol)   ; no ellipsis
  (remove-overlays (point-min) (point-max) 'st-arch-comment t)
  (save-excursion
    (goto-char (point-min))
    (while (re-search-forward st-arch-comment-regexp nil t)
      (let* ((beg (line-beginning-position))
             (end (min (point-max) (1+ (line-end-position))))
             (ov (make-overlay beg end)))
        (overlay-put ov 'st-arch-comment t)
        (overlay-put ov 'invisible st-arch-comment-symbol)))))

(defun st-show-arch-comments ()
  "Undo `st-hide-arch-comments'."
  (interactive)
  (remove-from-invisibility-spec st-arch-comment-symbol)
  (remove-overlays (point-min) (point-max) 'st-arch-comment t))

(defun st-toggle-arch-comments ()
  (interactive)
  (if (memq st-arch-comment-symbol buffer-invisibility-spec)
      (st-show-arch-comments)
    (st-hide-arch-comments)))
```

Same overlay-plus-invisibility-spec mechanism as your earlier dot-line hider, renamed to the `st-` convention and matching your current `⋅` marker. This is a flat filter (any line starting with `⋅`, regardless of nesting depth) rather than the depth-based `outline-hide-sublevels` folding — so it's a separate axis: use `M-1`/`M-2`/`M-3` to control how much of the annotation *hierarchy* shows, or `st-toggle-arch-comments` to strip all annotation lines at once and see just the raw code, undotted lines untouched either way.
---

I want to bind M-9 to toggle between hiding all architectural comments and showing everything.

---
```elisp
(with-eval-after-load 'outline
  (define-key outline-minor-mode-map (kbd "M-9") #'st-toggle-arch-comments))
```

Same pattern as your `M-1`/`M-0` bindings — scoped to `outline-minor-mode-map` so it only takes effect in buffers where outline-minor-mode is on, leaving `M-9`'s default `digit-argument` (numeric prefix arg) intact everywhere else.
---

The M-9 toggling shows only code lines that have been uncovered by M-0. When ON, it should show all non-architectural lines, when OFF it should show all lines AL and non-AL (where `AL` is shorthand for `architectural line`)

---

The bug: `outline-show-entry` (`M-0`) only reveals code that outline itself has un-folded at that point. `st-hide-arch-comments` never touched outline's own hiding — it only added/removed the `st-arch-comment` invisibility symbol — so any code still sitting under a folded heading stayed invisible regardless of the AL toggle. Fix: have the toggle also force outline to reveal everything first, then let AL-hiding take over as the only filter in play.

```elisp
(defun st-hide-arch-comments ()
  "Show only non-architectural (code) lines."
  (interactive)
  (outline-show-all)                      ; clear any outline folding first
  (add-to-invisibility-spec st-arch-comment-symbol)
  (remove-overlays (point-min) (point-max) 'st-arch-comment t)
  (save-excursion
    (goto-char (point-min))
    (while (re-search-forward st-arch-comment-regexp nil t)
      (let* ((beg (line-beginning-position))
             (end (min (point-max) (1+ (line-end-position))))
             (ov (make-overlay beg end)))
        (overlay-put ov 'st-arch-comment t)
        (overlay-put ov 'invisible st-arch-comment-symbol)))))

(defun st-show-arch-comments ()
  "Show everything: AL and non-AL lines alike."
  (interactive)
  (remove-from-invisibility-spec st-arch-comment-symbol)
  (remove-overlays (point-min) (point-max) 'st-arch-comment t)
  (outline-show-all))

(defun st-toggle-arch-comments ()
  (interactive)
  (if (memq st-arch-comment-symbol buffer-invisibility-spec)
      (st-show-arch-comments)
    (st-hide-arch-comments)))
```

With `outline-show-all` run first, every code line is unconditionally visible before the AL-hiding overlay pass runs, so ON shows all code regardless of prior `M-0`/`M-1`/`M-2`/`M-3` state, and OFF shows literally everything.

Side effect worth knowing: since `outline-show-all` fully expands the outline, toggling `M-9` resets whatever heading fold depth you'd set with `M-1`/`M-2`/`M-3` — pressing `M-9` twice gets you back to "everything visible," not back to your previous fold level. If you want that fold state preserved across the toggle, it'd need to be captured and restored explicitly (e.g. remembering the last `outline-hide-sublevels` argument and reapplying it in `st-show-arch-comments` instead of calling `outline-show-all`); say if that's what you want and I'll adjust it.

---

rewinding to the beginning and starting from scratch (deleting all elisp code developed thus far):
in the st-mode, for the whole buffer: I want outlining-mode turned on, I want all images to display, 
M-1 should show only lines with AL level 1
M-2 should show only lines with AL level 2 or lower (e.g. 1 and 2)
M-3 should show only lines with AL level 3 or lower
M-4 should show only lines with AL level 4 or lower
M-5 should show only lines with AL level 5 or lower
M-6 should show only lines with AL level 6 or lower
M-7 should show only lines with AL level 7 or lower
M-8 should show only lines with AL level 8 or lower
M-9 should show only lines with AL level 9 or lower
M-0 should toggle between showing everything and only non-AL lines
everywhere in the buffer

---

Fresh, self-contained `st-mode` covering all of this — outline recognition, image display, and the M-1…M-9 / M-0 bindings, replacing everything built up earlier. Needs `lexical-binding: t` at the top of whatever file this lives in, since the M-1…M-9 bindings are built via a loop of closures each capturing a different N.

```elisp
;;; -*- lexical-binding: t; -*-

(defvar st-al-char "⋅"
  "Character marking an architectural line (AL).")

(defvar st-default-image-width 400)

(defun st--line-al-level ()
  "AL level of the current line: count of leading ⋅ after whitespace, 0 if none."
  (save-excursion
    (beginning-of-line)
    (skip-chars-forward " \t")
    (let ((start (point)))
      (skip-chars-forward st-al-char)
      (- (point) start))))

;; --- images ---

(defun st-remove-images ()
  (interactive)
  (remove-overlays (point-min) (point-max) 'st-image t))

(defun st-display-images ()
  "Render ![alt][width](path) links as inline images."
  (interactive)
  (st-remove-images)
  (save-excursion
    (goto-char (point-min))
    (while (re-search-forward
            "!\\[\\([^]]*\\)\\]\\(?:\\[\\([0-9]+\\)\\]\\)?(\\([^)]+\\))"
            nil t)
      (let* ((width (if (match-string 2)
                         (string-to-number (match-string 2))
                       st-default-image-width))
             (path (match-string 3))
             (full-path (expand-file-name
                         path (file-name-directory (or buffer-file-name default-directory))))
             (beg (match-beginning 0))
             (end (match-end 0)))
        (when (and (file-exists-p full-path)
                   (image-type-available-p 'svg))
          (let* ((img (create-image full-path 'svg nil :max-width width))
                 (ov (make-overlay beg end)))
            (image-flush img)
            (overlay-put ov 'st-image t)
            (overlay-put ov 'display img)))))))

;; --- level-based line visibility (M-1..M-9, M-0) ---

(defvar st-level-invisible-symbol 'st-level-hidden)
(defvar-local st--non-al-only nil)

(defun st--hide-region (beg end)
  (let ((ov (make-overlay beg end)))
    (overlay-put ov 'st-level-overlay t)
    (overlay-put ov 'invisible st-level-invisible-symbol)))

(defun st-clear-level-overlays ()
  (remove-overlays (point-min) (point-max) 'st-level-overlay t))

(defun st-show-level (n)
  "Show only AL lines with level 1..N; hide deeper AL lines and all non-AL lines."
  (setq st--non-al-only nil)
  (add-to-invisibility-spec st-level-invisible-symbol)
  (st-clear-level-overlays)
  (save-excursion
    (goto-char (point-min))
    (while (not (eobp))
      (let ((level (st--line-al-level)))
        (unless (and (> level 0) (<= level n))
          (st--hide-region (line-beginning-position)
                            (min (point-max) (1+ (line-end-position))))))
      (forward-line 1))))

(defun st-show-everything ()
  (remove-from-invisibility-spec st-level-invisible-symbol)
  (st-clear-level-overlays))

(defun st-show-only-non-al ()
  (add-to-invisibility-spec st-level-invisible-symbol)
  (st-clear-level-overlays)
  (save-excursion
    (goto-char (point-min))
    (while (not (eobp))
      (when (> (st--line-al-level) 0)
        (st--hide-region (line-beginning-position)
                          (min (point-max) (1+ (line-end-position)))))
      (forward-line 1))))

(defun st-toggle-non-al ()
  "M-0: toggle between showing everything and showing only non-AL lines."
  (interactive)
  (if st--non-al-only
      (progn (st-show-everything) (setq st--non-al-only nil))
    (st-show-only-non-al)
    (setq st--non-al-only t)))

;; --- keymap & mode ---

(defvar st-mode-map
  (let ((map (make-sparse-keymap)))
    (dotimes (i 9)
      (let ((n (1+ i)))
        (define-key map (kbd (format "M-%d" n))
          (lambda () (interactive) (st-show-level n)))))
    (define-key map (kbd "M-0") #'st-toggle-non-al)
    map)
  "Keymap for `st-mode'.")

(define-minor-mode st-mode
  "Minor mode for architecturally-annotated code with leveled folding."
  :lighter " ST"
  :keymap st-mode-map
  (when st-mode
    (setq-local outline-regexp (concat "[ \t]*" (regexp-quote st-al-char) "+"))
    (setq-local outline-level #'st--line-al-level)
    (outline-minor-mode 1)
    (st-display-images)))
```

How it matches your spec: `M-N` (1–9) shows exactly the AL lines at level 1 through N and hides everything else — deeper AL lines and all non-AL/code lines alike — a flat classification computed per-line, not outline's own body-hiding. `M-0` is a separate, self-tracked toggle (`st--non-al-only`) between "everything visible" and "only non-AL lines visible," independent of whatever `M-N` last did, so it always behaves as a clean two-state flip. Turning on `st-mode` enables `outline-minor-mode` (with `outline-regexp`/`outline-level` wired to the same ⋅-counting logic, so TAB-cycling and other outline commands still recognize your headings) and immediately renders any `![alt][width](path)` images in the buffer.

Enable it in a buffer with `M-x st-mode`, or hook it to whatever major mode you're editing this DSL in, e.g. `(add-hook 'js-mode-hook #'st-mode)` if scoped appropriately per your earlier concern about `js-mode` collisions.

---

it appears that `(st-show-level ...)` needs a `(format ...)` also in `st-mod-map`

---

Good catch — the lambda-based keymap only works correctly if `lexical-binding: t` is genuinely active for the buffer, which only happens if that cookie is the literal first line of the whole file. Paste this snippet partway into an existing `init.el` and the cookie does nothing, so all nine `M-N` lambdas end up capturing the same (last) value of `n` instead of their own.

Cleaner fix: generate nine actual named functions with the level number spliced in as a literal, using `format`/`intern`, rather than relying on lambda closures at all. This works regardless of lexical-binding:

```elisp
(dotimes (i 9)
  (let ((n (1+ i)))
    (eval
     `(defun ,(intern (format "st-show-level-%d" n)) ()
        ,(format "Show only AL lines with level <= %d." n)
        (interactive)
        (st-show-level ,n)))))

(defvar st-mode-map
  (let ((map (make-sparse-keymap)))
    (dotimes (i 9)
      (let ((n (1+ i)))
        (define-key map (kbd (format "M-%d" n))
          (intern (format "st-show-level-%d" n)))))
    (define-key map (kbd "M-0") #'st-toggle-non-al)
    map)
  "Keymap for `st-mode'.")
```

Replace the earlier `st-mode-map` definition (the one with `lambda` inside `dotimes`) with these two forms. The `` ` `` (backquote) with `,n` splices the actual number into the generated `defun` body at the time `eval` runs, so `st-show-level-3`'s body literally contains `(st-show-level 3)` as a constant — no variable capture involved, so no closure/lexical-scoping bug is possible. The `define-key` loop was already safe (no lambdas there), but now it looks up the distinct named function per level via `intern`, matching the `format` you were expecting to see.

Everything else in `st-mode` (image display, outline setup, `st-toggle-non-al`) is unchanged.

