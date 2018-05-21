#!/usr/bin/env python

from __future__ import print_function
from jinja2 import Template as T
from random import random
import argparse, re, sys, os, shutil

expr = re.compile(r'^([^=]*)=(.*)$')

def install(prefix): shutil.copy(__file__, os.path.join(prefix,'jinja'))

def main(argv=None):
    p = argparse.ArgumentParser(); o = p.add_argument
    o('--file', '-f', help="jinja temlate file (default is stdin)", default='-')
    o('vars',         help="K=V variables to replace",  metavar='K=V', nargs='*')
    o('--install',    help="prefix to install 'jinja'", metavar='PREFIX')
    args = p.parse_args(argv)
    if args.install is not None:
        return install(args.install)
    else:
        out = jinja(args.file, *args.vars)
        print(out)
        return out

def jinja(filename, *kvstrings, **substitutions):
    if filename in (None, '-'):
        t = sys.stdin.read()
    else:
        with open(filename) as f: t = f.read()
    d = {re.match(expr, kv).groups() for kv in kvstrings}
    d.update(substitutions)
    return T(t).render(d)

# SELFTEST: {{ TEST }}
def test_jinja():
    val = str(random())
    res = main(['-f', __file__, 'TEST={}'.format(val)])
    assert "# SELFTEST: {}".format(val) in res

if __name__ == '__main__': main()
