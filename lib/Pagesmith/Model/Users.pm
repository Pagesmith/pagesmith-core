package Pagesmith::Model::Users;

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

## Base class shared by actions/components in Sanger::AdvCourses namespace

## Author         : James Smith <js5>
## Maintainer     : James Smith <js5>
## Created        : Thu, 23 Jan 2014
## Last commit by : $Author$
## Last modified  : $Date$
## Revision       : $Revision$
## Repository URL : $HeadURL$

use strict;
use warnings;
use utf8;

use version qw(qv); our $VERSION = qv('0.1.0');

use Pagesmith::Utils::ObjectCreator qw(bake);

use Const::Fast qw(const);
const my $DEFAULT_GROUP_STATE => 'open';
const my $GROUP_STATES => [
  [ 'open'      => 'Open group' ],        ## Open group - any one can join
  [ 'member'    => 'Restricted group' ],  ## Closed group - but can be seen (and joined)
  [ 'closed'    => 'Closed group' ],      ## Closed group - but cannot be seen (invite only)
  [ 'inactive'  => 'Inactive group' ],    ## Inactive group - can't join!
];
const my $DEFAULT_MEMBERSHIP_STATE => 'active';
const my $MEMBERSHIP_STATES => [
  [ 'active'    => 'Active' ],            ## Active member of group
  [ 'inactive'  => 'Inactive' ],          ## Person has had membership but they have temporarily inactivated it
  [ 'suspended' => 'Suspended membership' ],  ## Person has had membership but they have been temporarily suspended by admin...
  [ 'pending'   => 'Pending approval' ],  ## Request for membership has been made!
  [ 'invited'   => 'Invited' ],           ## User has been invited by admininstrator!
  [ 'banned'    => 'Banned' ],            ## Admin has banned person from group!
];
const my $DEFAULT_USER_STATE => 'pending';
const my $USER_STATES => [
  [ 'pending'    => 'Awaiting confirmation of email' ], ## Pending validation of email
  [ 'active'     => 'Active account' ],                 ## Active member
  [ 'inactive'   => 'Inactive account' ],               ## Inactive member - account has been suspended because of light use
  [ 'cancelled'  => 'Cancelled account' ],              ## Inactive member - account has been suspended by user..
  [ 'suspended'  => 'Suspended account' ],              ## Inactive member - account has been suspended by admin..
  [ 'banned'     => 'Account banned' ],                 ## Account has been banned
];

bake( {
  'mail_domain' => 'sanger.ac.uk',
  'relationships' => {
    'Membership' => {
      'objects' => [
        'user_id'      => 'User',
        'usergroup_id' => 'Usergroup',
      ],
      'additional' => [
        'status'     => { 'plural' => 'statuses', 'type' => 'enum', 'values' => $MEMBERSHIP_STATES, 'default' => $DEFAULT_MEMBERSHIP_STATE },
        'admin'      => { 'type' => 'boolean', 'default' => 'no' },
        'can_invite' => { 'type' => 'boolean', 'default' => 'no' }, ## For closed groups can send out invites...
      ],
      'audit'       => { qw(datetime both user_id both) },
    },
  },
  'objects' => {
    'User' => {
      'audit'      => { qw(datetime both user_id both) },
      'properties' => [
        'user_id'      => 'uid',
        'code'         => { 'type' => 'uuid', 'length' => 24, },
        'method'       => { 'type' => 'string', 'length' => 64, },
        'email'        => { 'type' => 'string', 'length' => 128, },
        'password'     => { 'type' => 'string', 'length' => 32, 'default' => q() },
        'name'         => { 'type' => 'string', 'length' => 128, },
        'admin'        => { 'type' => 'boolean', 'default' => 'no' },
        'status'       => { 'plural' => 'statuses', 'type' => 'enum', 'values' => $USER_STATES, 'default' => $DEFAULT_USER_STATE },
      ],
      'admin' => { 'by' => 'admin' },
      'fetch_by' => [
        { 'unique' => 1, 'keys' => [ 'method', 'code'  ] },
        { 'unique' => 1, 'keys' => [ 'method', 'email' ] },
        { 'unique' => 0, 'keys' => [ 'email' ] },
      ],
    },
    'Usergroup' => {
      'audit'       => { qw(datetime both user_id both) },
      'properties' => [
        'usergroup_id' => 'uid',
        'code'     => { 'type' => 'uuid', 'length' => 24, 'unique' => 1 },
        'name'     => { 'type' => 'string', 'length' => 128, },
        'description'   => { 'type' => 'text', },
        'status'   => { 'plural' => 'statuses', 'type' => 'enum', 'values' => $GROUP_STATES, 'default' => $DEFAULT_GROUP_STATE },
      ],
      'admin' => { 'by' => 'admin' },
      'related' => [
        'invites' => { 'from' => 'Invite' },
      ],
    },
    'Invite' => {
      'audit'       => { qw(datetime both user_id both) },
      'properties' => [
        'invite_id' => 'uid',
        'code'     => { 'type' => 'uuid', 'length' => 24, 'unique' => 1 },
        'name'     => { 'type' => 'string', 'length' => 128, },
        'email'    => { 'type' => 'string', 'length' => 128, },
      ],
      'related' => [
        'usergroup_id' => { 'to' => 'Usergroup', 'derived' => { 'code' => 'group_code', 'name' => 'group_name', 'description' => 'group_description' } },
      ],
    },
    'EmailChange' => {
      'audit'       => { qw(datetime both user_id both) },
      'properties' => [
        'emailchange_id' => 'uid',
        'code'        => { 'type' => 'uuid',    'length' => 24, 'unique' => 1 },
        'oldemail'    => { 'type' => 'String',  'length' => 128 },
        'newemail'    => { 'type' => 'String',  'length' => 128 },
        'expires_at'  => { 'type' => 'datetime' },
      ],
      'remove' => 1,
      'related' => [
        'user_id' => { 'to' => 'User' },
      ],
    },
    'PwChange' => {
      'audit'       => { qw(datetime both user_id both) },
      'properties' => [
        'pwchange_id' => 'uid',
        'code'        => { 'type' => 'uuid',    'length' => 24, 'unique' => 1 },
        'checksum'    => { 'type' => 'string',  'length' => 32, },
        'expires_at'  => { 'type' => 'datetime' },
      ],
      'remove' => 1,
      'related' => [
        'user_id' => { 'to' => 'User', 'derived' => { 'code' => 'user_code', 'password' => 'user_password' } },
      ],
    },
  },
} );

1;
