# vim-quickrun-job

Job runner module for [vim-quickrun](https://github.com/thinca/vim-quickrun)

This plugin is highly experimental and unstable.

## Requirements

- **Latest** Vim with `+channel`, `+job`, and `+timer` features.
- [vim-quickrun](https://github.com/thinca/vim-quickrun)

## Usage

In `quickrun_config`, add `'runner': 'job'`.

## Options

You can choose output mode of the channel.

```
'runner/job/out_mode': 'raw'  " default
```

`raw` mode may include broken output.
In this case, try `nl` mode.

For details, see `:help channel-mode`
