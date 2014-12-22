# asar-util - Atom-Shell Archive Utility

[![build status](http://img.shields.io/travis/bwin/asar-util.svg?style=flat-square)](https://travis-ci.org/bwin/asar-util)
[![dependencies](http://img.shields.io/david/bwin/asar-util.svg?style=flat-square)](https://david-dm.org/bwin/asar-util)
[![npm version](http://img.shields.io/npm/v/asar-util.svg?style=flat-square)](https://npmjs.org/package/asar-util)

Asar is a simple extensive archive format, it works like `tar` that concatenates all files together without compression, while having random access support.

## Features

* Support random access
* Use JSON to store files' information
* Very easy to write a parser

## Command line utility

### Install

```bash
$ npm install asar-util
```

### Usage

```bash
$ asar --help

  Usage: asar [options] [command]

  Commands:

    pack|p <dir> <output>
       create asar archive

    list|l <archive>
       list files of asar archive

    extract-file|ef <archive> <filename>
       extract one file from archive

    extract|e <archive> <dest>
       extract archive


  Options:

    -h, --help     output usage information
    -V, --version  output the version number

```

## Using programatically

### Example

```js
...
```
