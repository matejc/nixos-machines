# RaspberryPi image building and provisioning

My setup for devices in my home, published for others as an example.


## Image Build with Packer and Nix


### Requirements

- RaspberryPi (tested with Zero W and 4)
- Nix


### Build image command example

```shell
$ nix-shell image.nix --argstr password "root_password" --argstr wifi_name "some_wifi_ssid" --argstr wifi_password "some_wifi_password"
```


### dd built image on SD card

```shell
$ sudo dd if=./mnt/build/output-arm-image/raspios.img of=/dev/<storage_device>
```


## Klipper and Mainsail with Ansible


### Requirements

- Nix (run `nix-shell` in project's root directory), or
- Ansible


### Configuration


#### Ansible inventory example

```shell
$ cat provision/inventory.yml
---
all:
  children:
    printers:
      hosts:
        printer:
          ansible_host: 192.168.0.123
          ansible_user: pi
          ansible_python_interpreter: python3
          printer_mcu_serial: /dev/serial/by-id/usb-1a86_USB_Serial-if00-port0
          printer_trusted_clients:
            - 192.168.0.0/24
          printer_users:
            - username: guest
              password: guestguest
```

### Provision with Ansible

```shell
$ ansible-playbook -i provision/inventory.yml -l printer provision/printers.yml
```


## TODO: PiHole with Ansible
