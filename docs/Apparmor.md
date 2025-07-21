# AppArmor Tutorial for Rhino Linux

## Introduction to AppArmor

AppArmor is a Linux security module that provides Mandatory Access Control (MAC) by confining programs to a limited set of resources. It's included by default in Ubuntu and helps protect your system by restricting what applications can do.

## 1. Checking AppArmor Status

First, let's verify if AppArmor is running:

```bash
sudo apparmor_status
```

You should see output showing which profiles are loaded and in enforce/complain mode.

## 2. Basic AppArmor Commands

### List all profiles:
```bash
sudo aa-status
```

### Reload all profiles:
```bash
sudo systemctl reload apparmor
```

### Disable AppArmor (not recommended):
```bash
sudo systemctl stop apparmor
sudo systemctl disable apparmor
```

### Enable AppArmor:
```bash
sudo systemctl enable apparmor
sudo systemctl start apparmor
```

## 3. Working with Profiles

### Put a profile in complain mode (logs violations but doesn't enforce):
```bash
sudo aa-complain /path/to/binary
# Or for all profiles:
sudo aa-complain /etc/apparmor.d/*
```

### Put a profile back in enforce mode:
```bash
sudo aa-enforce /path/to/binary
# Or for all profiles:
sudo aa-enforce /etc/apparmor.d/*
```

### Disable a specific profile:
```bash
sudo ln -s /etc/apparmor.d/profile.name /etc/apparmor.d/disable/
sudo apparmor_parser -R /etc/apparmor.d/profile.name
```

## 4. Creating Custom Profiles

### Using aa-genprof to create a new profile:
1. Install the tools if needed:
```bash
sudo apt install apparmor-utils
```

2. Generate a profile for an application:
```bash
sudo aa-genprof /path/to/application
```
This will:
- Start the application in complain mode
- Guide you through creating rules based on the application's behavior

### Using aa-logprof to update profiles:
After running an application in complain mode, use this to analyze logs and update profiles:
```bash
sudo aa-logprof
```

## 5. Understanding Profile Files

Profiles are stored in `/etc/apparmor.d/`. A basic profile looks like:

```
#include <tunables/global>

/usr/bin/example {
  #include <abstractions/base>
  
  /etc/example.conf r,
  /var/log/example.log w,
  /tmp/example/* rw,
  
  capability net_bind_service,
  
  network inet tcp,
}
```

## 6. Common Use Cases

### Confining a web server:
```bash
sudo aa-genprof /usr/sbin/nginx
```

### Confining a custom application:
```bash
sudo aa-genprof /opt/myapp/bin/main
```

### Creating a profile for a Docker container:
```bash
sudo aa-genprof /usr/bin/docker
```

## 7. Troubleshooting

### Check AppArmor denials in logs:
```bash
sudo grep DENIED /var/log/syslog
# or
sudo journalctl -xe | grep apparmor
```

### Temporarily disable AppArmor for debugging:
Add to kernel boot parameters: `apparmor=0`

## 8. Advanced Topics

### Profile modes:
- `enforce` - policy is enforced
- `complain` - violations are logged but allowed
- `kill` - policy is enforced and violating processes are killed
- `unconfined` - no restrictions

### Profile flags:
- `ix` - inherit execute
- `px` - discrete profile execute
- `ux` - unconfined execute

## Conclusion

AppArmor provides powerful security for Ubuntu systems. Start by monitoring applications in complain mode, then gradually enforce restrictions based on their actual needs. The tools like `aa-genprof` and `aa-logprof` make profile creation manageable even for complex applications.

Remember to test profiles thoroughly before enforcing them in production environments!