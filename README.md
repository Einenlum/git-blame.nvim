# git-blame.nvim
A git blame plugin for Neovim written in Lua

## Installation
### Using [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'f-person/git-blame.nvim'
```

## Requirements
* Neovim >= 0.5.0
* git

## The Why
There were several Vim plugins providing this functionality, however most of them were
written in VimScript and didn't work well for me. [coc-git](https://github.com/neoclide/coc-git) also had
option for showing blame info, it worked really well for me, I like it. However,
recently I decided to switch to Neovim's builtin LSP instead of using CoC and having
something running on Node.js just for git blame was not the best thing.

## Demo
![demo](assets/demo.png?raw=true)

## Requirements
Neovim

## Configuration
#### Enabled
Enables git-blame.nvim on neovim startup.
You can toggle git blame messages on/off with the `:GitBlameToggle` command.

Default: `1`

```vim
let g:gitblame_enabled = 0
```

#### Message template
The template for the blame message that will be shown.

Default: `'  <author> • <date> • <summary>'`

Available options: `<author>`, `<committer>`, `<date>`, `<committer-date>`, `<summary>`, `<sha>`

```vim
let g:gitblame_message_template = '<summary> • <date> • <author>'
```

#### Date format
The [format](https://www.lua.org/pil/22.1.html) of the date fields.

Default: `%c`

Available options:
```
%r	relative date (e.g., 3 days ago)
%a	abbreviated weekday name (e.g., Wed)
%A	full weekday name (e.g., Wednesday)
%b	abbreviated month name (e.g., Sep)
%B	full month name (e.g., September)
%c	date and time (e.g., 09/16/98 23:48:10)
%d	day of the month (16) [01-31]
%H	hour, using a 24-hour clock (23) [00-23]
%I	hour, using a 12-hour clock (11) [01-12]
%M	minute (48) [00-59]
%m	month (09) [01-12]
%p	either "am" or "pm" (pm)
%S	second (10) [00-61]
%w	weekday (3) [0-6 = Sunday-Saturday]
%x	date (e.g., 09/16/98)
%X	time (e.g., 23:48:10)
%Y	full year (1998)
%y	two-digit year (98) [00-99]
%%	the character `%´
```

```vim
let g:gitblame_date_format = '%r'
```

#### Highlight group
The highlight group for virtual text.

Default: `Comment`

```vim
let g:gitblame_highlight_group = "Question"
```

#### `nvim_buf_set_extmark` optional parameters
`nvim_buf_set_extmark` is the function used for setting the virtual text.
You can view an up-to-date full list of options in the
[Neovim documentation](https://neovim.io/doc/user/api.html#nvim_buf_set_extmark()).

Warning: overwriting `id` and `virt_text` will break the plugin behavior.

```vim
let g:gitblame_set_extmark_options = {
	\ 'priority': 7,
	\ }
```

## Commands
#### Open the commit URL in browser
`:GitBlameOpenCommitURL` opens the commit URL of commit under the cursor.
Tested to work with GitHub and GitLab.

#### Enable/Disable git blame messages
* `:GitBlameToggle` toggles git blame on/off,
* `:GitBlameEnable` enables git blame messages,
* `:GitBlameDisable` disables git blame messages.

# Thanks To
* [coc-git](https://github.com/neoclide/coc-git) for some parts of code.
* [blamer.nvim](https://github.com/APZelos/blamer.nvim) for documentation inspiration.
