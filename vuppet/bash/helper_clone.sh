echo "Cloning..."
if [ ! -d /vagrant/project ] || [ ! "$(ls -A /vagrant/project)" ]
then
    echo "cloning the project starter..."
    cp -R /vagrant/starter /vagrant/project
#TODO also handle linking /vagrant/project/public/vendor/saf -> /vagrant/public ?
else
    echo "cannot clone into an existing project. remove or empty /project to re-clone"
fi