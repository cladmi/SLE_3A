#!/usr/bin/env perl

# Author: Jean-Edouard BABIN, je.babin in telecom-bretagne.eu
# Notable contributors:
#	Ronan Keryell, rk in enstb.org
#	Matthieu Moy, Matthieu.Moy in grenoble-inp.fr
#	François Revol, Francois.Revol in imag.fr
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# TODO
# - Base config should be in an external file.
# - Support multiple value for -a option to load more than 1 BranchID at once (already available for -n X,Y,Z)
# - TZID should not be statically set.
# - Add possibility to stop the script before starting to log on the website if option y or c match some string
#	(would be usefull for the cgi version where some users still try to load older project no longer existing
#
# For history see the end of the script
#
# If you want to contact author and contributors you can write to ade2ics in googlegroups.com

use strict;
use warnings;

use WWW::Mechanize;
use HTTP::Cookies;
use HTML::TokeParser;
use Term::ReadKey;
use Getopt::Long;
use Time::Local;
use POSIX;
use CGI qw(param header);

############################################
# Default school

# You may have to change this with your school name
# Script comes with configuration for TelecomBretagne, Ensimag, UPMF, UJF, UT, MA (case sensitive)
# You may need to create a new configuration for you school bellow

my $default_school = 'Ensimag';
############################################

# School configuration
my %default_config;
# For TelecomBretagne
$default_config{'TelecomBretagne'}{'u'} = 'http://edt.telecom-bretagne.eu/ade/';
$default_config{'TelecomBretagne'}{'l'} = '';
$default_config{'TelecomBretagne'}{'p'} = ''; # Should be commented if your ADE system don't need a password
$default_config{'TelecomBretagne'}{'w'} = 0;
$default_config{'TelecomBretagne'}{'c'} = 1;
$default_config{'TelecomBretagne'}{'d'} = undef;

# For Ensimag
$default_config{'Ensimag'}{'u'} = 'http://ade52-inpg.grenet.fr/ade/';
$default_config{'Ensimag'}{'l'} = 'voirIMATEL';
$default_config{'Ensimag'}{'p'} = ''; # Should be commented if your ADE system don't need a password
$default_config{'Ensimag'}{'w'} = 0;
$default_config{'Ensimag'}{'c'} = 0;
$default_config{'Ensimag'}{'d'} = undef;

# For UPMF
$default_config{'UPMF'}{'u'} = 'http://ade52-upmf.grenet.fr/';
$default_config{'UPMF'}{'l'} = '';
$default_config{'UPMF'}{'p'} = ''; # Should be commented if your ADE system don't need a password
$default_config{'UPMF'}{'w'} = 0;
$default_config{'UPMF'}{'c'} = 0;
$default_config{'UPMF'}{'d'} = undef;

# For UJF
$default_config{'UJF'}{'u'} = 'http://ade52-ujf.grenet.fr/';
$default_config{'UJF'}{'l'} = '';
$default_config{'UJF'}{'p'} = ''; # Should be commented if your ADE system don't need a password
$default_config{'UJF'}{'w'} = 0;
$default_config{'UJF'}{'c'} = 0;
$default_config{'UJF'}{'d'} = undef;

# For Mines Albi
$default_config{'MA'}{'u'} = 'http://ade.mines-albi.fr:8080/ade/';
$default_config{'MA'}{'l'} = '';
$default_config{'MA'}{'p'} = ''; # Should be commented if your ADE system don't need a password
$default_config{'MA'}{'w'} = 0;
$default_config{'MA'}{'c'} = 0;
$default_config{'MA'}{'d'} = undef;

# For Unviv Tours
$default_config{'UT'}{'u'} = 'http://emploidutemps.univ-tours.fr/ade/';
$default_config{'UT'}{'l'} = '';
$default_config{'UT'}{'p'} = ''; # Should be commented if your ADE system don't need a password
$default_config{'UT'}{'w'} = 0;
$default_config{'UT'}{'c'} = 1;
$default_config{'UT'}{'d'} = 'univ-tours.fr'; # univ-tours.fr or etu.univ-tours.fr

# For Univ Brest (UBO)
$default_config{'UBO'}{'u'} = 'http://ent.univ-brest.fr/ade/';
$default_config{'UBO'}{'l'} = '';
$default_config{'UBO'}{'p'} = ''; # Should be commented if your ADE system don't need a password
$default_config{'UBO'}{'w'} = 0;
$default_config{'UBO'}{'c'} = 1;
$default_config{'UBO'}{'d'} = undef;

my %opts;
my @tree;

# Output to UTF-8
binmode(STDOUT, ":encoding(UTF-8)");
$| = 1;

$opts{'s'} = $default_school;

if (!defined $ENV{REQUEST_METHOD}) {

	GetOptions(\%opts, 'y=s', 'n=s', 'a=s', 'u=s', 'l=s', 's=s', 'p:s', 'w!', 'v!', 'd=s', 'c!');

	$opts{'u'} = $opts{'u'} || $default_config{$opts{'s'}}{'u'};
	$opts{'l'} = $opts{'l'} || $default_config{$opts{'s'}}{'l'};
	$opts{'p'} = $opts{'p'} || $default_config{$opts{'s'}}{'p'};
	$opts{'w'} = $opts{'w'} || $default_config{$opts{'s'}}{'w'};
	$opts{'v'} = $opts{'v'} || $default_config{$opts{'s'}}{'v'};
	$opts{'d'} = $opts{'d'} || $default_config{$opts{'s'}}{'d'};
	$opts{'c'} = $opts{'c'} || $default_config{$opts{'s'}}{'c'};

	if (!(defined($opts{'a'}) xor defined($opts{'n'})) ) {
		print STDERR "Usage: $0 -a Alphabetical_path [-y Projet_name] [-s school_name] [-l login] [-p [password]] [-u ade_url] [-c [-d domain]] [-w] [-v]\n";
		print STDERR "Usage: $0 -n Numerical_value   [-y Projet_name] [-s school_name] [-l login] [-p [password]] [-u ade_url] [-c [-d domain]] [-w] [-v]\n";
		print STDERR " -a : alphabetical path through the ressource, encoded in ISO-8859-1 (see examples)\n";
		print STDERR " -n : numerical value of the ressource\n";
		print STDERR " -y : the projet name if needed\n";
		print STDERR " -s : school name. It loads a set of default value for -u -l -p -w -c -d for your school. Default school is : $default_school. Available school are (case sensitive):\n";
		print STDERR "\t- $_\n" foreach (keys %default_config);
		print STDERR " -u : the ADE location to peek into\n";
		print STDERR " -l : login name for authentication purpose\n";
		print STDERR " -p : password to use for authentication purpose\n";
		print STDERR "\t if you just use -p without password, you will be prompted for it. recommanded for security !\n";
		print STDERR " -w : write the schedule in time-stamped \"calendar.\" file to track modifications to your calendar.\n";
		print STDERR " -c : enable CAS Authentification, as used at Telecom Bretagne\n";
		print STDERR " -d : set realm to use for CAS authentification (useless for most CAS installation)\n";
		print STDERR " -v : enable verbose/debug output (will write file on disk)\n";
		print STDERR "\nSome examples:\n";
		print STDERR " $0 -l jebabin -p -y '2007-2008' -a 'Etudiants:FIP:FIP 3A 2007-2008:BABIN Jean-Edouard'\n";
		print STDERR " $0 -s Ensimag -p some_password -y 'ENSIMAG2009-2010' -a 'Enseignants:M:Moy Matthieu'\n";
		print STDERR " $0 -s Ensimag -p some_password -y 'ENSIMAG2009-2010' -n 717,1320,1321,1322,1324,1334,1324\n";
		print STDERR " even more:\n";
		print STDERR " $0 -c -l jebabin -p -y '2007-2008' -a 'Etudiants:FIP:FIP 3A 2007-2008:BABIN Jean-Edouard'\n";
		print STDERR " $0 -w -c -l keryell -p some_password -y '2007-2008' -a 'Enseignants:H à K:KERYELL Ronan'\n";
		print STDERR " $0 -u http://ade52-inpg.grenet.fr/ade/ -l voirIMATEL -p somepassword -y 'ENSIMAG2009-2010' -a 'Enseignants:M:Moy Matthieu'\n";
		exit 1;
	}
} else {
	print header(-type => 'text/calendar; method=request; charset=UTF-8;', -attachment => 'edt.ics');
	if (defined(param('a')) or defined(param('n'))) {
		$opts{'s'} = param('s') if (defined(param('s')));

		$opts{'u'} = $default_config{$opts{'s'}}{'u'};
		$opts{'l'} = $default_config{$opts{'s'}}{'l'};
		$opts{'p'} = $default_config{$opts{'s'}}{'p'};
		$opts{'w'} = $default_config{$opts{'s'}}{'w'};
		$opts{'v'} = $default_config{$opts{'s'}}{'v'};
		$opts{'d'} = $default_config{$opts{'s'}}{'d'};
		$opts{'c'} = $default_config{$opts{'s'}}{'c'};

		$opts{'a'} = param('a');
		$opts{'n'} = param('n');
		$opts{'y'} = param('y') if (defined(param('y')));
		$opts{'u'} = param('u') if (defined(param('u')));
		$opts{'l'} = param('l') if (defined(param('l')));
		$opts{'p'} = param('p') if (defined(param('p')));
		$opts{'w'} = param('w') if (defined(param('w')));
		$opts{'c'} = param('c') if (defined(param('c')));
		$opts{'d'} = param('d') if (defined(param('d')));
#		$opts{'v'} = param('v') if (defined(param('v')));
	} else {
		print "Usage: $0?n=Numerical_Value[&y=Project_Name][&s=school][&u=base_url][&l=login][&p=password][&w][&c][&d=domain]\n";
		print "       $0?a=Alphabetical_path[&y=Project_Name][&s=school][&u=base_url][&l=login][&p=password][&w][&c][&d=domain]\n";
		exit 1;
	}
}

if ((defined($opts{'p'})) and ($opts{'p'} eq "")) {
	print "Please input password: ";
	ReadMode('noecho');
	$opts{'p'} = ReadLine(0);
	chomp $opts{'p'};
	ReadMode('normal');
}

if ($opts{'w'}) {
	# Create a time stamped output file:
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
	my $output_file_name = sprintf("calendar.%d-%02d-%02d_%02d:%02d:%02d.ics",
				   $year+1900, $mon, $mday, $hour, $min, $sec);
	close(STDOUT);
	open(STDOUT, ">", $output_file_name) or die "open of " . $output_file_name . " failed!";
}

push (@tree,$opts{'y'});
if (defined($opts{'a'})) {
	foreach (split(':', $opts{'a'})) {
		push (@tree,$_);
		# $opts{'a'} is ProjectID:Category:branchId:branchId:branchId but of course in text instead of ID
		# The job is to find the latest branchId ID then parse schedule
    	}
}

my $mech = WWW::Mechanize->new(agent => 'ADEics 0.2', cookie_jar => {});


# login in
$mech->get($opts{'u'}.'standard/index.jsp');
debug_url($mech, '010', $opts{'v'});
die "Error 1 : failed to load welcome page. Check if base_url works." if (!$mech->success());

if ($opts{'c'}) {
	$mech->submit_form(fields => {username => $opts{'l'}, password => $opts{'p'}, domain => $opts{'d'}});
} else {
	$mech->submit_form(fields => {login => $opts{'l'}, password => $opts{'p'}});
}
debug_url($mech, '020', $opts{'v'});
die "Error 2 : Login failed." if (!$mech->success());

if ($opts{'c'}) {
	$mech->follow_link( n => 1 );
	debug_url($mech, '021', $opts{'v'});
	die "Error 2.1" if (!$mech->success());
}

# Getting projet list
$mech->get($opts{'u'}.'standard/projects.jsp');
debug_url($mech, '022', $opts{'v'});
die "Error 2.2 : Failed to load projets.jps. Check if ADE url ($opts{'u'}) works." if (!$mech->success());

# Choosing projectId
my $p = HTML::TokeParser->new(\$mech->content);
my $token = $p->get_tag("select");

my $projid = -1;
my %availableproject;
while (($projid == -1) && (my $token = $p->get_tag("option"))) {
	my $pname = $p->get_trimmed_text;
	if($pname eq $tree[0]) {
		$projid = $token->[1]{value};
	}
	$availableproject{$pname} = 1;
}
	
# ADE allow to select a project but no one has been selected
if (($projid == -1) && (%availableproject)) {
	reporterror("Project $tree[0] does not exist", "The requested project '$tree[0]' does not exist. Existing projects are :",%availableproject);
	die "Error 3 : $tree[0] does not exist";
} elsif (%availableproject) {
	$mech->submit_form(fields => {projectId => $projid});
	debug_url($mech, '040', $opts{'v'});
	die "Error 4 : Can't select $tree[0]." if (!$mech->success());
} else {
	warn "Assuming single project\n";
	# TODO: Check project name printed in the top frame of standard/projects.jsp request
}


if ($opts{'a'}) {
	# Usage of -a, we need to find its numerical value

	# We need to load tree.jsp to find category name
	$mech->get($opts{'u'}.'standard/gui/tree.jsp');
	debug_url($mech, '050', $opts{'v'});
	die "Error 5 : Can't load standard/gui/tree.jsp." if (!$mech->success());

	# So, find it
	$p = HTML::TokeParser->new(\$mech->content);
	$token = $p->get_tag("span");

	my $category;
	my %availablecategory;
	while ((!defined($category)) && (my $token = $p->get_tag("a"))) {
		my $categoryname = $p->get_trimmed_text;
		if($categoryname eq $tree[1]) {
			$category = $token->[1]{href};
		}
		$availablecategory{$categoryname} = 1;
		$token = $p->get_tag("span");
	}
	$category =~ s/.*\('(.*?)'\)$/$1/;

	if (!defined($category)) {
		reporterror("Path $tree[1] does not exist", "The value '$tree[1]' requested in your path does not exist. Existing value at this path level are :",%availablecategory);
		die "Error 6 : $tree[1] does not exist. Check argument to -a option.";
	}

	# We need to load the category chosen on command line to find branchID
	$mech->get($opts{'u'}.'standard/gui/tree.jsp?category='.$category.'&expand=false&forceLoad=false&reload=false&scroll=0');
	debug_url($mech, '070', $opts{'v'});
	die "Error 7 : Can't load standard/gui/tree.jsp?category=$category ..." if (!$mech->success());

	# We loop until last supplied branchID
	my $branchId;
	my $i=0;
	for (2..$#tree) {
		undef $branchId;
		$i++;

		# find branch
		$p = HTML::TokeParser->new(\$mech->content);
		$token = $p->get_tag("span");

		my %availablebranch;
		while ((!defined($branchId)) && (my $token = $p->get_tag("div"))) {
			my $text = $p->get_text;                                                                                                                                                                                                                                                                            
			$text = $1 if ($text =~  /(.*)\[IMG\]/);                                                                                                                                                                                                                                                            

			next if (length($text) != $i*3);                                  
			$token = $p->get_tag("span");
			$token = $p->get_tag("span");
			$token = $p->get_tag("a");

			my $branchname = $p->get_trimmed_text;
			if($branchname eq $tree[$_]) {
				$branchId = $token->[1]{href};
			}
			$availablebranch{$branchname} = 1;
		}

		debug_url($mech, "08".$_, $opts{'v'});

		if (!defined($branchId)) {
			reporterror("Path $tree[$_] does not exist", "The value '$tree[$_]' requested in your path does not exist. Existing value at this path level are :",%availablebranch);
			die "Error 8.$_ : $tree[$_] does not exist";
		}

		$branchId =~ s/.*\((\d+),\s+.*/$1/;
	
		if ($_ == $#tree) {
			$mech->get($opts{'u'}.'standard/gui/tree.jsp?selectId='.$branchId.'&reset=true&forceLoad=false&scroll=0');
		} else {
			$mech->get($opts{'u'}.'standard/gui/tree.jsp?branchId='.$branchId.'&expand=false&forceLoad=false&reload=false&scroll=0');
		}

	}

	$opts{'n'} = $branchId;
	debug_url($mech, '091', $opts{'v'});
	die "Error 9.1 : $tree[$#tree] does not exist" if (!defined($branchId));
	
}

# We run this part even if option a has been supllied because if this URL is not load the 'force displayed fields' part of the script did not work - quite strange!
if ($opts{'n'}) {
	$mech->get($opts{'u'}.'custom/modules/plannings/direct_planning.jsp?resources='.$opts{'n'});
	debug_url($mech, '092', $opts{'v'});
	die "Error 9.2 : Can't load custom/modules/plannings/direct_planning.jsp?resources=".$opts{'n'} if (!$mech->success());
}

# We need to choose a week
$mech->get($opts{'u'}.'custom/modules/plannings/pianoWeeks.jsp?forceLoad=true');
debug_url($mech, '100', $opts{'v'});
die "Error 10.0 : Can't load custom/modules/plannings/pianoWeeks.jsp?forceLoad=true." if (!$mech->success());

# then we choose all week
$mech->get($opts{'u'}.'custom/modules/plannings/pianoWeeks.jsp?searchWeeks=all');
debug_url($mech, '101', $opts{'v'});
die "Error 10.1 : Can't load custom/modules/plannings/pianoWeeks.jsp?searchWeeks=all." if (!$mech->success());

# force displayed fields
$mech->get($opts{'u'}.'custom/modules/plannings/appletparams.jsp');
debug_url($mech, '102', $opts{'v'});
die "Error 10.2 : failed to load config page." if (!$mech->success());
# Activity / Activités
$mech->field("showTabActivity", "true");	# Nom
$mech->field("showTabWeek", undef);	# Semaine
$mech->field("showTabDay", undef);		# Jour
$mech->field("showTabStage", undef);	# Stage
$mech->field("showTabDate", "true");		# Date
$mech->field("showTabHour", "true");		# Heure
$mech->field("aC", undef);				# Code
$mech->field("aTy", undef);			# Type
$mech->field("aUrl", undef);			# Url
$mech->field("showTabDuration", "true");	# Durée
$mech->field("aSize", undef);			# Capacité
$mech->field("aMx", undef);			# Nombre de siøges
$mech->field("aSl", undef);			# Siøges disponibles
$mech->field("aCx", undef);			# Code X
$mech->field("aCy", undef);			# Code Y
$mech->field("aCz", undef);			# Code Z
$mech->field("aTz", undef);			# Fuseau horaire
$mech->field("aN", undef);				# Notes
$mech->field("aNe", undef);			# Note de séance

# Trainees / Etudiants
$mech->field("showTabTrainees", "true");	# Nom
$mech->field("sC", undef);
$mech->field("sTy", undef);
$mech->field("sUrl", undef);
$mech->field("sE", undef);
$mech->field("sM", undef);
$mech->field("sJ", undef);
$mech->field("sA1", undef);
$mech->field("sA2", undef);
$mech->field("sZp", undef);
$mech->field("sCi", undef);
$mech->field("sSt", undef);
$mech->field("sCt", undef);
$mech->field("sT", undef);
$mech->field("sF", undef);
$mech->field("sCx", undef);
$mech->field("sCy", undef);
$mech->field("sCz", undef);
$mech->field("sTz", undef);

# Instructors / Enseignants
$mech->field("showTabInstructors", "true");	# Nom
$mech->field("iC", "false");
$mech->field("iTy", "false");
$mech->field("iUrl", "false");
$mech->field("iE", "false");
$mech->field("iM", "false");
$mech->field("iJ", "false");
$mech->field("iA1", "false");
$mech->field("iA2", "false");
$mech->field("iZp", "false");
$mech->field("iCi", "false");
$mech->field("iSt", "false");
$mech->field("iCt", "false");
$mech->field("iT", "false");
$mech->field("iF", "false");
$mech->field("iCx", "false");
$mech->field("iCy", "false");
$mech->field("iCz", "false");
$mech->field("iTz", "false");

# Rooms / Salles
$mech->field("showTabRooms", "true");	# Nom
$mech->field("roC", "false");
$mech->field("roTy", "false");
$mech->field("roUrl", "false");
$mech->field("roE", "false");
$mech->field("roM", "false");
$mech->field("roJ", "false");
$mech->field("roA1", "false");
$mech->field("roA2", "false");
$mech->field("roZp", "false");
$mech->field("roCi", "false");
$mech->field("roSt", "false");
$mech->field("roCt", "false");
$mech->field("roT", "false");
$mech->field("roF", "false");
$mech->field("roCx", "false");
$mech->field("roCy", "false");
$mech->field("roCz", "false");
$mech->field("roTz", "false");

# Resources / Equipements
$mech->field("showTabResources", "true");
$mech->field("reC", "false");
$mech->field("reTy", "false");
$mech->field("reUrl", "false");
$mech->field("reE", "false");
$mech->field("reM", "false");
$mech->field("reJ", "false");
$mech->field("reA1", "false");
$mech->field("reA2", "false");
$mech->field("reZp", "false");
$mech->field("reCi", "false");
$mech->field("reSt", "false");
$mech->field("reCt", "false");
$mech->field("reT", "false");
$mech->field("reF", "false");
$mech->field("reCx", "false");
$mech->field("reCy", "false");
$mech->field("reCz", "false");
$mech->field("reTz", "false");

# Category5 / used as Status at Telecom Bretagne 
$mech->field("showTabCategory5", "true");
$mech->field("c5C", "false");
$mech->field("c5Ty", "false");
$mech->field("c5Url", "false");
$mech->field("c5E", "false");
$mech->field("c5M", "false");
$mech->field("c5J", "false");
$mech->field("c5A1", "false");
$mech->field("c5A2", "false");
$mech->field("c5Zp", "false");
$mech->field("c5Ci", "false");
$mech->field("c5St", "false");
$mech->field("c5Ct", "false");
$mech->field("c5T", "false");
$mech->field("c5F", "false");
$mech->field("c5Cx", "false");
$mech->field("c5Cy", "false");
$mech->field("c5Cz", "false");
$mech->field("c5Tz", "false");

# Category6 / used as Groupes at Telecom Bretagne
$mech->field("showTabCategory6", "true");
$mech->field("c6C", "false");
$mech->field("c6Ty", "false");
$mech->field("c6Url", "false");
$mech->field("c6E", "false");
$mech->field("c6M", "false");
$mech->field("c6J", "false");
$mech->field("c6A1", "false");
$mech->field("c6A2", "false");
$mech->field("c6Zp", "false");
$mech->field("c6Ci", "false");
$mech->field("c6St", "false");
$mech->field("c6Ct", "false");
$mech->field("c6T", "false");
$mech->field("c6F", "false");
$mech->field("c6Cx", "false");
$mech->field("c6Cy", "false");
$mech->field("c6Cz", "false");
$mech->field("c6Tz", "false");

# Category7 / used as Modules at Telecom Bretagne
$mech->field("showTabCategory7", "true");
$mech->field("c7C", "false");
$mech->field("c7Ty", "false");
$mech->field("c7Url", "false");
$mech->field("c7E", "false");
$mech->field("c7M", "false");
$mech->field("c7J", "false");
$mech->field("c7A1", "false");
$mech->field("c7A2", "false");
$mech->field("c7Zp", "false");
$mech->field("c7Ci", "false");
$mech->field("c7St", "false");
$mech->field("c7Ct", "false");
$mech->field("c7T", "false");
$mech->field("c7F", "false");
$mech->field("c7Cx", "false");
$mech->field("c7Cy", "false");
$mech->field("c7Cz", "false");
$mech->field("c7Tz", "false");

# Category8 / used as Formation/UV at Telecom Bretagne
$mech->field("showTabCategory8", "true");
$mech->field("c8C", "false");
$mech->field("c8Ty", "false");
$mech->field("c8Url", "false");
$mech->field("c8E", "false");
$mech->field("c8M", "false");
$mech->field("c8J", "false");
$mech->field("c8A1", "false");
$mech->field("c8A2", "false");
$mech->field("c8Zp", "false");
$mech->field("c8Ci", "false");
$mech->field("c8St", "false");
$mech->field("c8Ct", "false");
$mech->field("c8T", "false");
$mech->field("c8F", "false");
$mech->field("c8Cx", "false");
$mech->field("c8Cy", "false");
$mech->field("c8Cz", "false");
$mech->field("c8Tz", "false");

$mech->submit_form();
debug_url($mech, '103', $opts{'v'});
die "Error 10.3 : failed to submit config page." if (!$mech->success());

# Get planning
$mech->get($opts{'u'}.'custom/modules/plannings/info.jsp?order=slot&light=true');
	# light remove some heading
	# order=slot sort by date (not needed for the script to work)
debug_url($mech, '110', $opts{'v'});
die "Error 11 : Can't load custom/modules/plannings/info.jsp." if (!$mech->success());

# Parse planning to get event
$p = HTML::TokeParser->new(\$mech->content);

print "BEGIN:VCALENDAR\n";
print "VERSION:2.0\n";
print "PRODID:-//Jeb//edt.pl//EN\n";
print "BEGIN:VTIMEZONE\n";
print "X-WR-CALNAME:ADE2ics\n";
#print "TZID:Europe/Paris\n";
#print "X-WR-TIMEZONE:Europe/Paris\n";
print "TZID:\"GMT +0100 (Standard) / GMT +0200 (Daylight)\"\n";
print "END:VTIMEZONE\n";
print "METHOD:PUBLISH\n";
ics_output($mech->content, $1);
print "END:VCALENDAR\n";

sub ics_output {
    # Parse the data and generate records that tends toward
    # http://www.ietf.org/rfc/rfc2445.txt :-)
	my $data = $_[0];
	my $p = HTML::TokeParser->new(\$data);
	
	$token = $p->get_tag("table");
	$token = $p->get_tag("tr");
	$token = $p->get_tag("tr");

	while ($token = $p->get_tag("tr")) {
		my $date;
		my $id;
		my $course;
		my $hour;
		my $duration;
		my $trainers;
		my $trainees;
		my $rooms;
		my $equipment;
		my $statuts;
		my $groupes;
		my $module;
		my $formation_UV;

		#######################################
		# This part is not generic enough to work well with all installation but has been largy improved in version 3.2
		#######################################

		# showTabDate
		$token = $p->get_tag("span");
		$date = $p->get_trimmed_text; # 12/05/2006

		# showTabActivity
		$token = $p->get_tag("a");
		$id = $token->[1]{href};
		$id =~ /\((\d+)\)/;
		$id = $1;
		$course = $p->get_trimmed_text; # INF 423 Cours 1 et 2

		# showTabHour
		$token = $p->get_tag("td");
		$hour = $p->get_trimmed_text; # 13h30 | 15:30

		# showTabDuration
		$token = $p->get_tag("td");
		$duration = $p->get_trimmed_text; # 2h50min | 2h | 50min

		# showTabTrainees
		$token = $p->get_tag("td");
		$trainees = $p->get_text('td'); #

		# showTabInstructors
		$token = $p->get_tag("td");
		$trainers = $p->get_text('td'); # LEROUX Camille

		# showTabRooms
		$token = $p->get_tag("td");
		$rooms = $p->get_text('td'); # B03-132A

		# showTabResources
		$token = $p->get_tag("td");
		$equipment = $p->get_text('td');

		# showTabCategory5
		$token = $p->get_tag("td");
		$statuts = $p->get_text('td'); # Validé

		# showTabCategory6
		$token = $p->get_tag("td");
		$groupes = $p->get_text('td'); # Groupe UV2 MAJ INF 423

		# showTabCategory7
		$token = $p->get_tag("td");
		$module = $p->get_text('td'); # FIP ELP103 Electronique numerique : Logique combinatoire

		# showTabCategory8
		$token = $p->get_tag("td");
		$formation_UV = $p->get_trimmed_text; # Enseignements INF S3 UV2 MAJ INF Automne Majeure INF UV2
		
		#######################################
		if(0) { #used for debug
		print "Date:		$date\n";
		print "Id:		$id\n";
		print "course:		$course\n";
		print "hour:		$hour\n";
		print "duration:	$duration\n";
		print "trainers:	$trainers\n";
		print "trainees:	$trainees\n";
		print "rooms:		$rooms\n";
		print "equipment:	$equipment\n";
		print "statuts:		$statuts\n";
		print "groupes:	$groupes\n";
		print "module:		$module\n";
		print "formation_UV:	$formation_UV\n";
		print "\n";
		next;
		}
		#######################################
		
		$date =~ m|(\d+)/(\d+)/(\d+)|;
		my $ics_day = sprintf("%02d%02d%02d",$3,$2,$1);
		$hour =~ m|(\d+)[h:](\d+)|i;
		
		my $ics_start_hour = $1;
		my $ics_start_minute = $2;
		my $ics_start_date = $ics_day.'T'.sprintf("%02d%02d00",$1,$2);

		my $ics_duration_hours;
		my $ics_duration_minutes;
		my $ics_stop_date;
		my $ics_duration;
		
		if ($duration =~ m|^(\d+)h(\d+)|) {
			$ics_duration_hours = $1;
			$ics_duration_minutes = $2;
		} elsif ($duration =~ m|^(\d+)h|) {
			$ics_duration_hours = $1;
			$ics_duration_minutes = 0;
		} elsif ($duration =~ m|^(\d+)m|) {
			$ics_duration_hours = 0;
			$ics_duration_minutes = $1;
		} else {
			die "Error 14 : date $duration can't be parsed";
		}
	
		my $ics_end_hours = $ics_start_hour+$ics_duration_hours;
		my $ics_end_minutes = $ics_start_minute+$ics_duration_minutes;

		while ($ics_end_minutes >= 60) {
			$ics_end_minutes -= 60;
			$ics_end_hours += 1;
		}
	
		$ics_stop_date = $ics_day.'T'.sprintf('%02d%02d00',$ics_end_hours, $ics_end_minutes);
		$ics_duration = "PT".sprintf('%02d', $ics_duration_hours)."H".sprintf('%02d', $ics_duration_minutes)."M0S";

		my ($tssec,$tsmin,$tshour,$tsmday,$tsmon,$tsyear,$tswday,$tsyday,$tsisdst) = gmtime();
		my $dtstamp = sprintf("%02d%02d%02dT%02d%02d%02dZ", $tsyear+1900, $tsmon + 1, $tsmday, $tshour, $tsmin, $tssec);

		print "BEGIN:VEVENT\n";
		print "DTSTART;TZID=Europe/Paris:$ics_start_date\n";
		print "DTEND;TZID=Europe/Paris:$ics_stop_date\n";
		print "SUMMARY:$course\n";
		print "DTSTAMP:$dtstamp\n";
		print "UID:edt-$id-0\n";		
		print "DESCRIPTION:";
		print "Salle : $rooms".'\n';
		print "Enseignants : $trainers".'\n';
		print "Cours : $course".'\n' if ($course !~ /^\s+$/);
		print "Etudiants : $trainees".'\n' if ($trainees !~ /^\s+$/);
		print "Groupes	: $groupes".'\n' if ($groupes !~ /^\s+$/);
		print "Modules	: $module".'\n' if ($module !~ /^\s+$/);
		print "Formations/UV : $formation_UV".'\n' if ($formation_UV !~ /^\s+$/);
		print "Equipements : $equipment".'\n' if ($equipment !~ /^\s+$/);
		print "Statuts	: $statuts" if ($statuts !~ /^\s+$/);
		print "\n";
		print "LOCATION:$rooms\n";
		print "URL;VALUE=URI:".$opts{'u'}."custom/modules/plannings/eventInfo.jsp?eventId=$id\n";
		print "END:VEVENT\n";
	}
}

sub reporterror {
	my ($summary, $desc1, %desc2) = @_;


	my ($tssec,$tsmin,$tshour,$tsmday,$tsmon,$tsyear,$tswday,$tsyday,$tsisdst) = gmtime();
	my $dtstamp = sprintf("%02d%02d%02dT%02d%02d%02dZ", $tsyear+1900, $tsmon + 1, $tsmday, $tshour, $tsmin, $tssec);
	my $edtstamp = sprintf("%02d%02d%02dT%02d%02d%02dZ", $tsyear+1900, $tsmon + 1, $tsmday, $tshour+2, $tsmin, $tssec);

	print "BEGIN:VCALENDAR\n";                                                                                                                                                                                                                                                                                                    
	print "VERSION:2.0\n";                                                                                                                                                                                                                                                                                                        
	print "PRODID:-//Jeb//edt.pl//EN\n";                                                                                                                                                                                                                                                                                          
	print "BEGIN:VTIMEZONE\n";                                                                                                                                                                                                                                                                                                    
	print "X-WR-CALNAME:ADE2ics\n";                                                                                                                                                                                                                                                                                               
	print "TZID:\"GMT +0100 (Standard) / GMT +0200 (Daylight)\"\n";                                                                                                                                                                                                                                                              
	print "END:VTIMEZONE\n";                                                                                                                                                                                                                                                                                                      
	print "METHOD:PUBLISH\n";                                                                                                                                                                                                                                                                                                     
	print "BEGIN:VEVENT\n";
	print "DTSTART:$dtstamp\n";
	print "DTEND:$edtstamp\n";
	print "DTSTAMP:$dtstamp\n";
	print "UID:edt-out\n";
	print "SUMMARY:$summary\n";
	print "DESCRIPTION:";
	print "$desc1".'\n';
	print "$_".'\n' foreach (sort keys %desc2);
	print "\n";
	print "END:VEVENT\n";
	print "END:VCALENDAR\n";
}

sub debug_url {
	my ($mech, $file_number, $d) = @_;

	if ($d) {
		my $file_name = "ade2ics-debug-".$file_number.".html";
		open(FILE, ">$file_name") or die "Can't open file $file_name: $!";
		print FILE "<!--".$mech->uri()."-->\n";
		print FILE $mech->content."\n";
		close(FILE);
	}
}


__END__

History (doesn't follow commit revision)

Reversion 3.5 2010/12/23
Improved tree parsing
Improved hours parsing
Fix a problem with some version of module used by WWW::Mechanize
Support for UBO

Revision 3.4 2010/05/08
Improve output when path (-a) is invalid
	now return a valid calendar event talling what part is incorrect and what value could be used

Revision 3.3 2010/05/06
Change option -d by option -v (for verbose/debug)
Add option -d to supply a domain name for CAS authentication
Improved usage message
Add default configuration for Université de Tours and Mines d'Albi

Revision 3.2 2010/05/01
Add support for UPMF and UJF based on the work of FranÁois Revol
	The script now choose what has to be displayed in the planning table, this improve its parsing.
	Project name is now no longer mandatory
Fix a bug in CGI version, y option was ignored

Revision 3.1 2010/04/24
Use telecom-bretagne.eu instead of enst-bretagne.fr in the TelecomBretagne default configuration
Now return a valid calendar event (using current time) when project doesn't exist. So CGI users now see a more useful message 
Fix a bug preventing Location to be correctly set in some case
Fix CGI Usage message.

Revision 3.0 2009/10/05
Changed debug $file_number value for files to be sorted
Now use -y for Project name, -a for alphabetical path, -n to supply branchId.
	Based on work from Matthieu Moy
Also changed -c for cas, -s for school and -w for write

Revision 2.9 2009/10/04
Add TZID=Europe/Paris for each event as per Matthieu Moy (Ensimag) try.
	Having TZID in this format for each event and globaly has "GMT +0100 (Standard) / GMT +0200 (Daylight)" seems to make every calendar program happy...
Added debug_url to dump debug as file (Matthieu Moy (Ensimag))
More precise error messages. (Matthieu Moy (Ensimag))

Revision 2.8 2009/09/03
Fixed a bug that skiped half of the event.
Duration is now OK, it no longer have minutes > 59, thanks to Matthieu Moy (Ensimag)

Revision 2.7 2009/09/03
Allow -s -d -t switch to be negated with -nos --nod --not
Add an example for Ensimag
Add -e switch to select base configuration with a school name.
Minor bugfix

Revision 2.6 2008/09/19
Handle date with : instead of h

Revision 2.6 2008/09/10
Bug fix ($opts{'p'})

Revision 2.5 2008/09/09
Password can be read from stdin

Revision 2.4 2008/09/09
In-line help message improvment (keryell)

Revision 2.3 2007/09/18
Should now work with outlook 2002 (Thanks to C. Lohr)

Revision 2.2 2007/09/09
Can now be used with CAS authentification
Updated to work with new EDT installation

Revision 2.1 2007/03/14
Now send 'edt.ics' filename when using HTTP

Revision 2.0 2007/03/06
New way to get planning (much much faster) with info.jsp
TZID change for client that don't understand Europe/Paris

Revision 1.5 2006/10/11
Simpler way to get all weeks (thanks Erka !)
Change debug message to STDERR

Revision 1.4 2006/10/11
Show all weeks, including current one. bad code, but works...
Change OUTPUT to STDOUT, closing it then opening it to a file.

Revision 1.3 2006/09/26
Keep all the records in the calendar output.
Cleaned up output routine.
Rename the output file with an .ics extension.

Revision 1.2 2006/09/26
Improved documentation.
Now try to catch all the weeks in the calendar (TODO: to query first the
existing weeks or use the all weeks option of EDT?...).
Added a time-stamped output file option with -t.
