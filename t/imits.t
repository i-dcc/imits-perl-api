#!/usr/bin/env perl

use strict;
use warnings FATAL => 'all';

use FindBin;
use lib "$FindBin::Bin/lib";
use Log::Log4perl ':levels';
use MyTest::iMits;

Log::Log4perl->easy_init( $WARN );

Test::Class->runtests;
