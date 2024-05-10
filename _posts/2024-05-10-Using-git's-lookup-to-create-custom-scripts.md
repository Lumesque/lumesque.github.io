---
layout: post
title: "Using git's lookup to create custom scripts"
date: 2024-05-10 16:50:53 -0000
categories: [git,python,pypi,init,hatch,workflows,git-workflows]
tags: 
- git
- python
- pypi
- init
- hatch
- workflows
- git-workflows
---

## Table of Contents

- [Python Directory Builder](#python-directory-builder)
- [Automating Git Workflows](#automating-git-workflows)
- [Using gits lookup](#using-gits-lookup)
- [The Script](#the-script)
- [Git-pyinit](#git-pyinit)



Repositories, and their differences between companies and authors in those companies, can make it harder to dictate what is up to author preference or what is a company standard. Using cookie-cutter python builders, and using common github workflows can create a common structure that can help unblur that line. But what would that script look like?

### Python Directory Builder

For building, I've been a big fan of [hatch](https://hatch.pypa.io/latest). It's genuinely a really fun tool to mess around in, and with, and it's far more powerful than I can talk about here (and that's just what I understand about it and I hardly know shit about it). If you ever have an afternoon, should definitely take a look at it!

In short, hatch creates a common directory structure for both your project and it's tests, creates the licenses, and basically all the things you need to start off.

When you create a project, it'll create a directory structure like this, and that's what I'll be using moving forward for use in this script, mainly because it has everything you need, but if you want to do it yourself, really all we're using it for is creating a directory, but it's better to standardize imo.

![dir-structure](/assets/images/directory_structure.png)

### Automating git workflows

Git workflows are a great help in making sure projects are formatted in a manner that is easy to read, and is common amongst individuals, as well as allowing for others to contribute to the project and keep to the standards. For creating github workflows, you'll have to have a __token__ that allows you to have workflow control.

Lets take a look at an example one that uses `isort`

```yaml
name: Linting Stage

on: [push]

jobs:
    build:
      runs-on: ubuntu-latest
      strategy:
        matrix:
          python-version: ['3.8']
      steps:
      - uses: actions/checkout@v3
      - name: Set Up Python ${{ matrix.python-version }}
        uses: actions/setup-python@v3
        with:
          python-version: ${{ matrix.python-version }}
      - name: Install Dependencies
        run: |
          python -m pip install --upgrade pip
          pip install isort

      - name: Analyzing code with isort
        run: |
          isort $(git ls-files '*.py') --check-only
```

These yamls can get way more complicated, and way more interesting, but I won't really talk about those here.

The script will need to do the following:
1. Fill in `runs-on`
2. Fill in `python-version`
3. Create `run: | ...` for each command, with specific flags

### Using gits lookup

If you've ever wondered how git can deal with so many different commands, it's because most are their own script. For instance, when you type in `git commit`, it actually looks along a path for a script called `git-commit`. We can use this to basically add an alias for git, without having to add it ourselves.

Lets create an example script to run on the command line. Make sure it's along your path, and call it `git-hello_world`

```bash
#!/usr/bin/bash

### Example script to show how git can be called

echo 'Hello, world!'
```

We get the following output:

![git-output](/assets/images/git_outputs.png)

So now all thats left is to make the script!

### The script

For ease of purpose, I decided to make a toml file that will read in what we want. The file will have this structure

```toml
[build]
python_version = [
"3.8",
]
runs-on = "ubuntu-latest"

[yaml]
active = [
"lint",
"tests"
]

[lint]
active = [
"isort",
"flake8",
]

[lint.isort]
flags = [
'--check-only',
]
```

1. __build:__ This will house our runs-on, and our various python-versions
2. __yaml:__ This will house what sections we want to run

Lets create something to house these, and something to house the overall results per tool we want to use
```python
from dataclasses import dataclass, field, InitVar
@dataclass
class TomlResults:
    name: str
    runs_on: str
    py_vers: list
    tools: list

@dataclass
class Tool:
    name: str
    command: InitVar[str] = field(default=None)
    yaml_command: str = field(init=False)
    active: bool = True
    flags: list = field(default_factory=list)
    file_command: str = field(default="$(git ls-files '*.py')")

    def __post_init__(self, command):
        self.command = command or self.name
        # Just have this for debug representation
        self.yaml_command = self.command

    def __str__(self):
        return f"{self.command} {self.file_command} {' '.join(self.flags)}"
```
We use the string so that we can just straight use them in a string format

Parsing tomls is super easy using `toml`, basically reading the toml looks like this

```python
import toml
filepath = "/path/to/config.toml"
with open(filepath) as f:
   results = toml.load(f)
```

Then we just have to parse for each of the sections (build, yaml, and the results from yaml). Lets start with build. We just need to know the `python_version` and the `runs-on`.

```python
build = results.get("build", {})
py_verses = build.get("python_version", ["3.8"])
runs_on = build.get("runs_on", "ubuntu-latest")
```

Simple enough, and grabbing the actives in yaml is just as simple

```python
yamls = results.get("yaml", {}).get("active", [])
```

Why use the defaults here? Well, this allows for no iterations if it's empty without us having to check. The for loop will just simply not execute, and so our template won't be written, which without all the information we'd just be making a blank template anyway.

So now we just loop over, and grab things we want. I chose to use `flags` as a list for flags to add to the command, `file_command` for the file_command to find files, as well as support for a `default` flag so if you want to do something for each, you won't have to put that in every section.

```python
for yaml in yamls:
    tools = results.get(yaml, {})
    active = tools.get("active", [])
    default = tools.get("default", [{}])
    default = {k: v for d in default for k, v in d.items()}
    _end = []
    for tool in active:
        tool_section = tools.get(tool, {})
        _end.append(
            Tool(
                name=tool_section.get("name", tool),
                command=tool_section.get("command", None),
                flags=tool_section.get("flags", default.get("flags", [])),
                file_command=tool_section.get(
                    "file_command", default.get("file_command", "$(git ls-files '*.py')")
                ),
                active=tool_section.get("active", True),
            )
        )
        yield TomlResults(name=yaml, runs_on=_runs_on, py_vers=_py_vers, tools=_end)
```

With all the info, now all we have to do is mesh it all together in writing and formatting the yaml files. For each of these tools, we create a yaml like this
```python
def format_template(results: TomlResults) -> str:
    template = """
    name: Linting Stage

    on: [push]

    jobs:
        build:
          runs-on: {runs_on}
          strategy:
            matrix:
              python-version: {py_vers}
          steps:
          - uses: actions/checkout@v3
          - name: Set Up Python ${{{{ matrix.python-version }}}}
            uses: actions/setup-python@v3
            with:
              python-version: ${{{{ matrix.python-version }}}}
          - name: Install Dependencies
            run: |
              python -m pip install --upgrade pip
              pip install {yaml_commands}
    """.format(
        runs_on=results.runs_on,
        py_vers=str(results.py_vers),
        yaml_commands=" ".join([tool.yaml_command for tool in results.tools if tool.active]),
    )
```

I used .format for readability since the template itself has things it wants to substitude later on (that's why there's so many {} around the `matrix.python-version`, it pops off two on each side so at the end we get a correct format), but using an f string is fine too

now for each tool, we just add to the template
```python
    for tool in results.tools:
        if not tool.active:
            continue
        template += f"""
          - name: Analyzing code with {tool.name}
            run: |
              {tool}
        """
```
The `active` portion means that you can specificy it to turn off easily in the toml, just using `active = false`

And thats it, putting it altogether, and just combining it with `git init`, we can get a script that generates and does this all for us!

### Git-pyinit

To see the script in action, check out [my git-pyinit script here](https://github.com/Lumesque/git-pyinit), or `pip install git-pyinit` and mess around with it and the config!
