echo "Restoring Stached Application Project..."
if [ ! -d /vagrant/local-dev.project ] || [ ! "$(ls -A /vagrant/local-dev.project)" ]
then
    echo "nothing to restore..."
else
    echo "moving local-dev.project to project"
    mv -T /vagrant/local-dev.project /vagrant/project
fi