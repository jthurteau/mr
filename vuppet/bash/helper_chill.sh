echo "Toning down SELinux..."
setenforce Permissive
systemctl stop firewalld.service