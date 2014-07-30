package Pagesmith::Support::Users;

#+----------------------------------------------------------------------
#| Copyright (c) 2014 Genome Research Ltd.
#| This file is part of the User account management extensions to
#| Pagesmith web framework.
#+----------------------------------------------------------------------
#| The User account management extensions to Pagesmith web framework is
#| free software: you can redistribute it and/or modify it under the
#| terms of the GNU Lesser General Public License as published by the
#| Free Software Foundation; either version 3 of the License, or (at
#| your option) any later version.
#|
#| This program is distributed in the hope that it will be useful, but
#| WITHOUT ANY WARRANTY; without even the implied warranty of
#| MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#| Lesser General Public License for more details.
#|
#| You should have received a copy of the GNU Lesser General Public
#| License along with this program. If not, see:
#|     <http://www.gnu.org/licenses/>.
#+----------------------------------------------------------------------

## Author         : James Smith <js5@sanger.ac.uk>
## Maintainer     : James Smith <js5@sanger.ac.uk>
## Created        : 30th Apr 2014

## Last commit by : $Author$
## Last modified  : $Date$
## Revision       : $Revision$
## Repository URL : $HeadURL$

use strict;
use warnings;
use utf8;

use version qw(qv); our $VERSION = qv('0.1.0');

## Base class for actions/components in Users namespace

use base qw(Pagesmith::ObjectSupport);
use Pagesmith::Utils::ObjectCreator qw(bake);

bake();

1;
__END__

Purpose
-------

The purpose of the Pagesmith::Support::Users module is to
place methods which are to be shared between the following modules:

* Pagesmith::Action::Users
* Pagesmith::Component::Users

Common functionality can include:

* Default configuration for tables, two-cols etc
* Database adaptor calls
* Accessing configurations etc

Some default methods for these can be found in the
Pagesmith::ObjectSupport from which this module is derived:

  * adaptor( $type? ) -> gets an Adaptor of type Pagesmith::Adaptor::Users::$type
  * my_table          -> simple table definition for a table within the site
  * admin_table       -> simple table definition for an admin table (if different!)
  * me                -> user object (assumes the database being interfaced has a
                         User table keyed by "email"...

