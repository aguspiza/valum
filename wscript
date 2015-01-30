#!/usr/bin/env python

import glob

VERSION=(0,1,0)
APPNAME='valum'

top='.'
out='build'

def options(opt):
    opt.load('compiler_c')

def configure(conf):
    conf.load('compiler_c vala')

    # conf.env.append_unique('VALAFLAGS', ['--enable-experimental-non-null'])

    conf.check_cfg(package='glib-2.0', atleast_version='2.32', mandatory=True, uselib_store='GLIB', args='--cflags --libs')
    conf.check_cfg(package='ctpl', atleast_version='0.3.3', mandatory=True, uselib_store='CTPL', args='--cflags --libs')
    conf.check_cfg(package='gee-0.8', atleast_version='0.6.4', mandatory=True, uselib_store='GEE', args='--cflags --libs')
    conf.check_cfg(package='libsoup-2.4', atleast_version='2.38', mandatory=True, uselib_store='SOUP', args='--cflags --libs')
    conf.check_cfg(package='libnm-glib', atleast_version='0.9.4', mandatory=True, uselib_store='NM', args='--cflags --libs')

    # libfcgi does not provide a .pc file...
    conf.check(lib='fcgi', mandatory=True, uselib_store='FCGI', args='--cflags --libs')

    # configure examples
    conf.recurse(glob.glob('examples/*'))

def build(bld):
    # build a static library
    bld.stlib(
        packages    = ['glib-2.0', 'libsoup-2.4', 'gee-0.8', 'ctpl', 'fcgi', 'libnm-glib'],
        target      = 'valum',
        gir         = 'Valum-{}.{}'.format(*VERSION),
        source      = bld.path.ant_glob('src/**/*.vala'),
        uselib      = ['GLIB', 'CTPL', 'GEE', 'SOUP', 'FCGI', 'NM'],
        vapi_dirs   = ['vapi'])

    # build examples recursively
    bld.recurse(glob.glob('examples/*'))

    # build tests
    bld.recurse('tests')
