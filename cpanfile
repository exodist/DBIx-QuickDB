# This file is generated by Dist::Zilla::Plugin::CPANFile v6.024
# Do not edit this file directly. To change prereqs, edit the `dist.ini` file.

requires "Carp" => "0";
requires "Digest::SHA" => "0";
requires "Fcntl" => "0";
requires "File::Copy::Recursive" => "0";
requires "File::Path" => "0";
requires "File::Temp" => "0";
requires "IPC::Cmd" => "0";
requires "Importer" => "0.024";
requires "Module::Pluggable" => "2.7";
requires "POSIX" => "0";
requires "Scalar::Util" => "0";
requires "Test2" => "1.302120";
requires "Test2::API" => "1.302120";
requires "Test2::V0" => "0.000097";
requires "Test::More" => "1.302120";
requires "Time::HiRes" => "0";
requires "parent" => "0";
requires "perl" => "5.012000";

on 'test' => sub {
  requires "Capture::Tiny" => "0.20";
};

on 'configure' => sub {
  requires "ExtUtils::MakeMaker" => "0";
};

on 'develop' => sub {
  requires "DBD::MariaDB" => "1.00";
  requires "DBD::Pg" => "v3.5.0";
  requires "DBD::SQLite" => "1.44";
  requires "DBD::mysql" => "4.00";
  requires "Test::Pod" => "1.41";
};
