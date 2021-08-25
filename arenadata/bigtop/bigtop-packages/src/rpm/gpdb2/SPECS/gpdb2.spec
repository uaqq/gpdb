# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
%define man_dir %{_mandir}
%define _tmppath /var/tmp

%if  %{?suse_version:1}0
%define bin_gpdb /usr/lib/gpdb
%define doc_gpdb %{_docdir}/%{name}
%define autorequire yes
%else
%define bin_gpdb /usr/lib/gpdb
%define doc_gpdb %{_docdir}/%{name}-%{gpdb_version}
%define autorequire yes
%endif

%if 0%{?rhel} == 7
Requires:xerces-c, libuv
%endif

%if %{_vendor} == "alt"
Requires: libuv
%define autorequire nopython nopython3
%endif

%if %{_vendor} == "suse"
Requires:libxerces-c-3_1, libuv1
%endif

Name: gpdb2
Version: %{gpdb2_version}
Release: %{gpdb2_release}
Summary: Greenplum MPP database enginer
URL: https://github.com/greenplum-db/gpdb
Group: Development/Libraries
Buildroot: %{_topdir}/INSTALL/%{name}-%{version}
License: ASL 2.0
Source0: gpdb2-%{gpdb2_base_version}.tar.gz
Source1: do-component-build
Source2: install_gpdb.sh
Source3: do-component-configure
#BIGTOP_PATCH_FILES
AutoReqProv: %{autorequire}




%if %{_vendor} == "alt"
%set_verify_elf_method skip
%endif


%description
gpdb

%package loaders
Summary: Greenplum Loaders
Group: System/Daemons
AutoReqProv: %{autorequire}

%description loaders
Greenplum Loaders

%package -n gpperfmon
Summary: Greenplum gpperfmon
Group: System/Daemons
Requires: gpdb2 = %{gpdb2_version}
Conflicts:  adbcc-gp-ext
AutoReqProv: %{autorequire}

%description -n gpperfmon
Greenplum gpperfmon

%prep
%setup -n %{name}-%{gpdb2_base_version}

#BIGTOP_PATCH_COMMANDS

%build


%install
%__rm -rf $RPM_BUILD_ROOT
bash %{SOURCE3} %{bin_gpdb} $RPM_BUILD_ROOT %{gpdb2_base_version} %{gpdb2_release}
bash %{SOURCE1}
bash %{SOURCE2} %{bin_gpdb}
mkdir -p $RPM_BUILD_ROOT%{bin_gpdb}
cp -f -r %{bin_gpdb}/*  $RPM_BUILD_ROOT/

%files
%defattr(-,root,root)
%{bin_gpdb}
%exclude %{bin_gpdb}/bin/gpmmon
%exclude %{bin_gpdb}/bin/gpsmon
%exclude %{bin_gpdb}/bin/gpperfmoncat.sh
%exclude %{bin_gpdb}/bin/gpperfmon_install
%exclude %{bin_gpdb}/sbin/gpmon_catqrynow.py
%exclude %{bin_gpdb}/lib/gpperfmon

%changelog

%files loaders
%defattr(-,root,root)
%{bin_gpdb}/bin/gpload*
%{bin_gpdb}/bin/gpfdist
%{bin_gpdb}/lib/
%{bin_gpdb}/greenplum_path.sh

%files -n gpperfmon
%{bin_gpdb}/bin/gpmmon
%{bin_gpdb}/bin/gpsmon
%{bin_gpdb}/bin/gpperfmoncat.sh
%{bin_gpdb}/bin/gpperfmon_install
%{bin_gpdb}/sbin/gpmon_catqrynow.py
%{bin_gpdb}/lib/gpperfmon