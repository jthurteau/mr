echo "Stashing Application Project..."
if [ ! -d /vagrant/project ] || [ ! "$(ls -A /vagrant/project)" ]
then
    echo "nothing to put in the closet..."
else
    echo "moving project to local-dev.project"
    mv -T /vagrant/project /vagrant/local-dev.project
fi