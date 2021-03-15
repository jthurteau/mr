if [ ! -e ~/.bashrc ] || ! grep -q "poor detection of vagrant windows host" ~/.bashrc
then
    echo " " >> ~/.bashrc
    echo "## The (2) lines below fix poor detection of vagrant windows host" >> ~/.bashrc
    echo "# possibly fixed in Windows 10 1909, or only applies to RHEL(7?)" >> ~/.bashrc
    echo "#stty sane" >> ~/.bashrc
    echo "#export TERM=linux" >> ~/.bashrc
    echo " " >> ~/.bashrc
fi