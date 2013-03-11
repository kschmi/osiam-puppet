# Class: osiam
#
# This class deploys the osiam war(s) into an existinc application server.
#
# Parameters:
#   [*ensure*]      - Wether to install or remove osiam. Valid arguments are absent or present.
#   [*version*]     - Version of osiam artifacts to deploy.
#   [*webappsdir]   - Tomcat7 webapps directory path.
#   [*owner*]       - Artifact owner on filesystem.
#   [*group*]       - Artifact group on filesystem.
#
# Actions:
#
#
# Requires:
#   maven installed
#   puppet-maven module
#   java 1.7
#   tomcat 7
#
# Sample Usage:
#   class { 'osiam':
#       ensure     => present,
#       version    => '0.2-SNAPSHOT'
#       webappsdir => '/var/lib/tomcat7/webapps'
#    }
#
# Authors:
#   Kevin Viola Schmitz <k.schmitz@tarent.de>
#
class osiam (
    $ensure,
    $version,  
    $webappsdir,
    $owner          = 'tomcat',
    $group          = 'tomcat',
) {
    case $ensure {
        present: {
            case $version {
                /.*-SNAPSHOT$/: {
                    $repository = 'http://repo.osiam.org/snapshots'
                    $aspath = "${repository}/org/osiam/ng/authorization-server/${version}"
                    $ocpath = "${repository}/org/osiam/ng/oauth2-client/${version}"

                    exec { 'checkauthorizationserverwar':
                        path     => '/bin:/usr/bin',
                        command  => "rm -rf ${webappsdir}/authorization-server{,.war}",
                        before  => Maven['authorization-server'],
                        unless   => "test \
                            \"$(curl -s ${aspath}/$(wget -O- ${aspath} 2>&1 | grep '.war' | grep '.md5' | sed -e 's/.*href=\"\\(.*md5\\)\">.*$/\1/' | sed 's/\\.\\.//' | tail -n 1))\" = \
                            \"$(md5sum ${webappsdir}/authorization-server.war | awk -F' ' '{ print \$1 }')\""
                    }
                    exec { 'checkoauth2clientwar':
                        path    => '/bin:/usr/bin',
                        command => "rm -rf ${webappsdir}/oauth2-client{,.war}",
                        before  => Maven['oauth2-client'],
                        unless  => "test \
                            \"$(curl -s ${ocpath}/$(wget -O- ${ocpath} 2>&1 | grep '.war' | grep '.md5' | sed -e 's/.*href=\"\\(.*md5\\)\">.*$/\1/' | sed 's/\\.\\.//' | tail -n 1))\" = \
                            \"$(md5sum ${webappsdir}/oauth2-client.war | awk -F' ' '{ print \$1 }')\"",
                    }
                }
                default: {
                    $repository = 'http://repo.osiam.org/releases'
                }
            }

            maven { 'authorization-server':
                ensure     => $ensure,
                path       => "${webappsdir}/authorization-server.war",
                groupid    => 'org.osiam.ng',
                artifactid => 'authorization-server',
                version    => $version,
                packaging  => 'war',
                repos      => $repository,
                notify     => Exec['permissions'],
            }

            maven { 'oauth2-client':
                ensure     => $ensure,
                path       => "${webappsdir}/oauth2-client.war",
                groupid    => 'org.osiam.ng',
                artifactid => 'oauth2-client',
                version    => $version,
                packaging  => 'war',
                repos      => $repository,
                notify     => Exec['permissions'],
            }

            exec { 'permissions':
                path        => '/bin',
                command     => "chown ${owner}:${group} ${webappsdir}/authorization-server.war ${webappsdir}/oauth2-client.war",
                refreshonly => true,
            }

        }
        absent: {
            file { "${webappsdir}/authorization-server.war":
                ensure => absent,
                backup  => false,
            }
            file { "${webappsdir}/authorization-server":
                ensure  => absent,
                force   => true,
                backup  => false,
                require => File["${webappsdir}/authorization-server.war"],
            }
            file { "${webappsdir}/oauth2-client.war":
                ensure => absent,
                backup  => false,
            }
            file { "${webappsdir}/oauth2-client":
                ensure  => absent,
                force   => true,
                backup  => false,
                require => File["${webappsdir}/oauth2-client.war"],
            }
        }
        default: {
            fail("Ensure value not valid. Use 'present' or 'absent'")
        }
    }
}
