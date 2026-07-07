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
