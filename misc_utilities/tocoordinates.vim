syntax off
setlocal noautoindent
setlocal nocindent
setlocal nosmartindent
setlocal indentexpr=
g!/position = /normal dd/g
%s/\s*position.* "//
%s/";//
normal ggdd
%normal I{
%normal A},
%s/ /,/g
normal ggO{
normal Go}
normal Gk$x
