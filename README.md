Achievements
============
[![MELPA](http://melpa.org/packages/achievements-badge.svg)](http://melpa.org/#/achievements)

Purpose
-------

Achievements.el is meant to be a fun way to learn about Emacs.  There
is so much to learn about Emacs, that it can be quite daunting.  Using
an achievements system can hopefully make it fun.  Achievements.el
definitely doesn't take itself too seriously.

It is in a very rough state and any help is appreciated.  Especially,
since no single person can know everything about Emacs,
achievements.el will need contributions by many people to be really
useful.  So if you have ideas, send a pull request, open an issue, or
just spread the word.

Installation
------------

The easiest way to install emacs achievements is through
[MELPA](http://melpa.org).  To do this on a recent version of Emacs, add the
following to your .emacs:

    (add-to-list 'package-archives '("melpa" . "http://melpa.milkbox.net/packages/"))
    (package-initialize)

Then run `package-list-packages` and install achievements via the interface.
Alternately, you can run `(package-install 'achievements)` via `M-:` or the
scratch buffer.

Usage
-----

After installation, simply add `(require 'achievements)` to your .emacs if you
wish it to be loaded everytime.

There are two main entry points to the achievements package, namely:

 - `achievements-list-achievements` which shows a list of all the
   known achievements and whether you have earned them or not.  This
   (re)calculates which achievements you have earned.  Similar
   achievements are usually listed close to each other in this list.
   That's the only hint I'm going to give you.
 - `achievements-mode` is a global minor mode which runs an idle timer
   (controlled by `achievements-idle-time`) to (re)calculate which
   achievements you have earned.  Unfortunately, the recalculation can
   be somewhat slow, so you may not wish to run with this mode
   enabled.  Many achievements can be deduced without
   `achievements-mode` running.  Therefore, you might want to only
   keep it on when you are trying to unlock a particular achievement.
   On the other hand, if you run with it disabled, you'll never know
   the pleasure of recieving a "You've earned the XXX achievement!"
   message.

With very few exceptions, an achievement once achieved will stay achieved.
Achievements can be earned by running commands, setting variables, installing
packages, or just about any other thing you can think of.

P.S. No cheating! (unless you want to)

History
-------

I was introduced to the idea by
[this reddit discussion](http://www.reddit.com/r/emacs/comments/ook6a/does_something_like_this_exist_for_emacs/)
about
[a similar feature for Visual Studio](http://channel9.msdn.com/achievements/visualstudio).
A few days ago I started thinking about achievements.el again.  I
couldn't stop thinking about it, and sometimes the only way for me to
move on is to start working on it.  So there you have it.

There is also another similar project
[achievements-mode](https://github.com/Fuco1/achievements-mode).  We
are hoping the two will be merged at some point.

Contributing
------------

If you have an idea for an achievement, or a bug that needs to be fixed, head
over to [the repository](https://bitbucket.org/gvol/emacs-achievements/) and
open a pull request or an issue.