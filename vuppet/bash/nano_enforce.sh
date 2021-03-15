if [ ! -e ~/.bashrc ] || ! grep -q "set nano as the default editor" ~/.bashrc
then
    echo " " >> ~/.bashrc
    echo "## The (2) lines below set nano as the default editor" >> ~/.bashrc
    echo "export EDITOR='nano'" >> ~/.bashrc
    echo "export VISUAL='nano'" >> ~/.bashrc
    echo " " >> ~/.bashrc
fi