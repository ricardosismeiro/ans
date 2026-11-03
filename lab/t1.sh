git clone https://github.com/ricardosismeiro/ans/


ssh-keygen -t rsa -b 2048 -C “user”
ssh-copy-id -i ~/.ssh/id_rsa.pub vm-ans-user@10.10.0.1


ansible-inventory -i inventory/hosts.yml --graph




