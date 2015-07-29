# ************************************************************************* 
# Copyright (c) 2014-2015, SUSE LLC
# 
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
# 1. Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
# 
# 2. Redistributions in binary form must reproduce the above copyright
# notice, this list of conditions and the following disclaimer in the
# documentation and/or other materials provided with the distribution.
# 
# 3. Neither the name of SUSE LLC nor the names of its contributors may be
# used to endorse or promote products derived from this software without
# specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
# ************************************************************************* 

# ------------------------
# Model module
# ------------------------

package Web::MREST::CLI;

use 5.012;
use strict;
use warnings;

use Exporter qw( import );  # Exporter was first released with perl 5
use File::HomeDir;    # File::HomeDir was not in CORE (or so I think)
use File::Spec;       # File::Spec was first released with perl 5.00405




=head1 NAME

Web::MREST::CLI - CLI components for Web::MEST-based applications




=head1 VERSION

Version 0.276

=cut

our $VERSION = '0.276';




=head1 DESCRIPTION

Top-level module of the L<Web::MREST::CLI> distribution. Exports some
"generalized" functions that are used internally and might also be useful for
writing CLI clients in general.

=cut



=head1 EXPORTS

=cut

our @EXPORT_OK = qw( normalize_filespec );




=head1 FUNCTIONS

=head2 normalize_filespec

Given a filename (path) which might be relative or absolute, return an absolute
version. If the path was relative, it will be anchored to the home directory of
the user we are running as.

=cut

sub normalize_filespec {
    my $fs = shift;
    my $is_absolute = File::Spec->file_name_is_absolute( $fs );
    if ( $is_absolute ) {
        return $fs;
    }
    return File::Spec->catfile( File::HomeDir->my_home, $fs );
}


1;
