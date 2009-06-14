use strict;
use warnings;
use Test::More tests => 3;

BEGIN { use_ok 'Catalyst::Test', 'PSNIC' }
BEGIN { use_ok 'PSNIC::Controller::Preferences' }

ok( request('/preferences')->is_success, 'Request should succeed' );


