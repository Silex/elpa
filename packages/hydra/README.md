[![Build Status](https://travis-ci.org/abo-abo/hydra.svg?branch=master)](https://travis-ci.org/abo-abo/hydra)

This is a package for GNU Emacs that can be used to tie related
commands into a family of short bindings with a common prefix - a
Hydra.

![hydra](http://oremacs.com/download/Hydra.png)

Once you summon the Hydra through the prefixed binding (the body + any
one head), all heads can be called in succession with only a short
extension.

The Hydra is vanquished once Hercules, any binding that isn't the
Hydra's head, arrives.  Note that Hercules, besides vanquishing the
Hydra, will still serve his orignal purpose, calling his proper
command.  This makes the Hydra very seamless, it's like a minor mode
that disables itself auto-magically.

## Simplified usage

Here's how to quickly bind the examples bundled with Hydra:

```cl
(require 'hydra-examples)
(hydra-create "C-M-y" hydra-example-move-window-splitter)
(hydra-create "M-g" hydra-example-goto-error)
(hydra-create "<f2>" hydra-example-text-scale)
```

## Using Hydra for global bindings

But it's much better to just take the examples as a template and write
down everything explicitly:

```cl
(defhydra hydra-zoom (global-map "<f2>")
  "zoom"
  ("g" text-scale-increase "in")
  ("l" text-scale-decrease "out"))
```

With the example above, you can e.g.:

```cl
(key-chord-define-global "tt" 'hydra-zoom/body)
```

In fact, since `defhydra` returns the body symbol, you can even write
it like this:

```cl
(key-chord-define-global
 "tt"
 (defhydra hydra-zoom (global-map "<f2>")
  "zoom"
  ("g" text-scale-increase "in")
  ("l" text-scale-decrease "out")))
```

If you like key chords so much that you don't want to touch the global
map at all, you can e.g.:

```
(key-chord-define-global
 "hh"
 (defhydra hydra-error ()
   "goto-error"
   ("h" first-error "first")
   ("j" next-error "next")
   ("k" previous-error "prev")))
```

You can also substitute `global-map` with any other keymap, like
`c++-mode-map` or `yas-minor-mode-map`.

See the [introductory blog post](http://oremacs.com/2015/01/20/introducing-hydra/) for more information.

## Using Hydra for major-mode or minor-mode bindings

Here's an example:

```cl
(defhydra lispy-vi (lispy-mode-map "C-z")
  "vi"
  ("l" forward-char)
  ("h" backward-char)
  ("j" next-line)
  ("k" previous-line))
```

## Can Hydras can be helpful?

They can, if

```cl
(setq hydra-is-helpful t)
```

This is the default setting. In this case, you'll get a hint in the
echo area consisting of current Hydra's base comment and heads.  You
can even add comments to the heads like this:

```
(defhydra hydra-zoom (global-map "<f2>")
  "zoom"
  ("g" text-scale-increase "in")
  ("l" text-scale-decrease "out"))
```

With this, you'll see `zoom: [g]: in, [l]: out.` in your echo area,
once the zoom Hydra becomes active.

## Colorful Hydras

Since version `0.5.0`, Hydra's heads all have a color associated with them:

- *red* (default) means the calling this head will not vanquish the Hydra
- *blue* means that the Hydra will be vanquished after calling this head

In all the older examples, all heads are red by default. You can specify blue heads like this:

```cl
(global-set-key
 (kbd "C-c C-v")
 (defhydra toggle ()
   "toggle"
   ("a" abbrev-mode "abbrev" :color blue)
   ("d" toggle-debug-on-error "debug" :color blue)
   ("f" auto-fill-mode "fill" :color blue)
   ("t" toggle-truncate-lines "truncate" :color blue)
   ("w" whitespace-mode "whitespace" :color blue)
   ("q" nil "cancel")))
```

Or, since the heads can inherit the color from the body, the following is equivalent:

```cl
(global-set-key
 (kbd "C-c C-v")
 (defhydra toggle (:color blue)
   "toggle"
   ("a" abbrev-mode "abbrev")
   ("d" toggle-debug-on-error "debug")
   ("f" auto-fill-mode "fill")
   ("t" toggle-truncate-lines "truncate")
   ("w" whitespace-mode "whitespace")
   ("q" nil "cancel")))
```

The above Hydra is very similar to this code:

```cl
(global-set-key (kbd "C-c C-v t") 'toggle-truncate-lines)
(global-set-key (kbd "C-c C-v f") 'auto-fill-mode)
(global-set-key (kbd "C-c C-v a") 'abbrev-mode)
```

However, there are two important differences:

- you get a hint like this right after <kbd>C-c C-v</kbd>:

        toggle: [t]: truncate, [f]: fill, [a]: abbrev, [q]: cancel.

- you can cancel <kbd>C-c C-v</kbd> with a command while executing that command, instead of e.g.
getting an error `C-c C-v C-n is undefined` for <kbd>C-c C-v C-n</kbd>.
