# nunchux notes

- Cache and just/npm plugins: I think it could be nice with a caching
invalidaotr that is the direcotry that the user is in. currently when in ~/a it
may show just files there. When the user moves to ~/b those just recipes still
show because they are cached. When the menu refreshes in ~/b the items will
dissapear. Maybe we could know this already in the cache and say that just
recipes (and npm scripts) are only valid for the directory where they were found.

- it could be nice to have the current sizing options, but also add a "max"
width/height that would make the menu not exceed a certain size.

- maybe the popup should open centered in the pane that is in focus, if that is
  possible.

<!-- vim: set ft=markdown ts=2 sw=2 et: -->
