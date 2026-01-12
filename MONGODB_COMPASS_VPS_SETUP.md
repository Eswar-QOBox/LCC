# 🔐 MongoDB Compass to VPS Connection Guide

A comprehensive guide for securely connecting MongoDB Compass from your local PC to a MongoDB instance running on a VPS.

---

## 📋 Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Detailed Setup](#detailed-setup)
  - [Step 1: Configure MongoDB on VPS](#step-1-configure-mongodb-on-vps)
  - [Step 2: Enable Authentication](#step-2-enable-authentication)
  - [Step 3: Create Admin User](#step-3-create-admin-user)
  - [Step 4: Configure Firewall](#step-4-configure-firewall)
  - [Step 5: Connect from MongoDB Compass](#step-5-connect-from-mongodb-compass)
- [Connection String Formats](#connection-string-formats)
- [Security Best Practices](#security-best-practices)
- [Troubleshooting](#troubleshooting)
- [Alternative Connection Methods](#alternative-connection-methods)
- [Verification Checklist](#verification-checklist)

---

## Prerequisites

Before starting, ensure you have:

- ✅ **MongoDB installed** on your VPS (Ubuntu/Debian recommended)
- ✅ **SSH access** to your VPS with root/sudo privileges
- ✅ **MongoDB Compass** installed on your local PC
  - Download: [https://www.mongodb.com/try/download/compass](https://www.mongodb.com/try/download/compass)
- ✅ **VPS Public IP Address** (e.g., `31.97.231.92`)
- ✅ **Your Local PC Public IP Address**
  - Find it: [https://ifconfig.me](https://ifconfig.me) or [https://whatismyipaddress.com](https://whatismyipaddress.com)
- ✅ **UFW (Uncomplicated Firewall)** installed on VPS (usually pre-installed on Ubuntu)

---

## Quick Start

For experienced users, here's the TL;DR version:

```bash
# 1. SSH into VPS
ssh root@<VPS_IP>

# 2. Edit MongoDB config
sudo nano /etc/mongod.conf
# Set: bindIp: 127.0.0.1,<VPS_PUBLIC_IP>
# Enable: security.authorization: enabled

# 3. Restart MongoDB
sudo systemctl restart mongod

# 4. Create admin user
mongosh
use admin
db.createUser({user: "admin", pwd: "StrongPassword123", roles: ["root"]})

# 5. Configure firewall
sudo ufw allow from <YOUR_PC_PUBLIC_IP> to any port 27017

# 6. Connect from Compass
mongodb://admin:StrongPassword123@<VPS_PUBLIC_IP>:27017/admin?authSource=admin
```

---

## Detailed Setup

### Step 1: Configure MongoDB on VPS

#### 1.1 SSH into Your VPS

```bash
ssh root@<VPS_IP>
# or
ssh username@<VPS_IP>
```

Replace `<VPS_IP>` with your actual VPS IP address (e.g., `31.97.231.92`).

#### 1.2 Locate MongoDB Configuration File

The configuration file location depends on your installation:

- **Standard installation**: `/etc/mongod.conf`
- **MongoDB Atlas/Cloud**: May vary
- **Docker installation**: Check container configuration

For standard installations:

```bash
sudo nano /etc/mongod.conf
```

#### 1.3 Configure Network Binding

Find the `net` section and update `bindIp`:

**Before:**
```yaml
net:
  port: 27017
  bindIp: 127.0.0.1
```

**After:**
```yaml
net:
  port: 27017
  bindIp: 127.0.0.1,<VPS_PUBLIC_IP>
```

**Example:**
```yaml
net:
  port: 27017
  bindIp: 127.0.0.1,31.97.231.92
```

> ⚠️ **Important**: 
> - Never use `0.0.0.0` in production (exposes MongoDB to entire internet)
> - Always include `127.0.0.1` for local connections
> - Use your VPS's actual public IP address

#### 1.4 Save and Exit

- **Nano**: Press `Ctrl + X`, then `Y`, then `Enter`
- **Vi/Vim**: Press `Esc`, type `:wq`, then `Enter`

---

### Step 2: Enable Authentication

#### 2.1 Enable Security Authorization

In the same `/etc/mongod.conf` file, find or add the `security` section:

```yaml
security:
  authorization: enabled
```

**Complete configuration example:**
```yaml
net:
  port: 27017
  bindIp: 127.0.0.1,31.97.231.92

security:
  authorization: enabled

storage:
  dbPath: /var/lib/mongodb
  journal:
    enabled: true
```

#### 2.2 Restart MongoDB Service

```bash
sudo systemctl restart mongod
```

#### 2.3 Verify MongoDB is Running

```bash
sudo systemctl status mongod
```

You should see `active (running)`. If not, check logs:

```bash
sudo journalctl -u mongod -n 50
```

---

### Step 3: Create Admin User

#### 3.1 Access MongoDB Shell

```bash
mongosh
```

If `mongosh` is not found, try:
```bash
mongo
```

#### 3.2 Switch to Admin Database

```js
use admin
```

#### 3.3 Create Root User

```js
db.createUser({
  user: "admin",
  pwd: "StrongPassword123",
  roles: ["root"]
})
```

**Expected output:**
```json
{
  ok: 1
}
```

> 💡 **Password Best Practices:**
> - Use a strong password (min 12 characters)
> - Include uppercase, lowercase, numbers, and special characters
> - Store password securely (password manager)

#### 3.4 Verify User Creation

```js
db.getUsers()
```

You should see your admin user listed.

#### 3.5 Exit MongoDB Shell

```js
exit
```

---

### Step 4: Configure Firewall

#### 4.1 Check UFW Status

```bash
sudo ufw status
```

If UFW is inactive, enable it:

```bash
sudo ufw enable
```

#### 4.2 Get Your Local PC Public IP

Visit one of these sites from your local PC:
- [https://ifconfig.me](https://ifconfig.me)
- [https://whatismyipaddress.com](https://whatismyipaddress.com)
- [https://api.ipify.org](https://api.ipify.org)

**Example:** `49.204.161.61`

#### 4.3 Allow Your IP Through Firewall

```bash
sudo ufw allow from <YOUR_PC_PUBLIC_IP> to any port 27017
```

**Example:**
```bash
sudo ufw allow from 49.204.161.61 to any port 27017
```

#### 4.4 Verify Firewall Rules

```bash
sudo ufw status numbered
```

**Expected output:**
```
Status: active

     To                         Action      From
     --                         ------      ----
[1]  27017                      ALLOW       49.204.161.61
```

#### 4.5 Remove Old/Unnecessary Rules (Optional)

If you have old LAN IP rules that are no longer needed:

```bash
# List numbered rules
sudo ufw status numbered

# Delete specific rule
sudo ufw delete <rule_number>
```

**Example:**
```bash
sudo ufw delete 2  # Removes rule #2
```

---

### Step 5: Connect from MongoDB Compass

#### 5.1 Open MongoDB Compass

Launch MongoDB Compass on your local PC.

#### 5.2 Enter Connection String

Use one of these connection string formats:

**Standard Format:**
```
mongodb://admin:StrongPassword123@<VPS_PUBLIC_IP>:27017/admin?authSource=admin
```

**Example:**
```
mongodb://admin:StrongPassword123@31.97.231.92:27017/admin?authSource=admin
```

**With Additional Options:**
```
mongodb://admin:StrongPassword123@31.97.231.92:27017/admin?authSource=admin&ssl=false&directConnection=true
```

#### 5.3 Alternative: Fill Form Manually

If you prefer using the form:

1. **Hostname**: `<VPS_PUBLIC_IP>` (e.g., `31.97.231.92`)
2. **Port**: `27017`
3. **Authentication**: 
   - **Username**: `admin`
   - **Password**: `StrongPassword123`
   - **Authentication Database**: `admin`

#### 5.4 Test Connection

Click **Connect** or **Test Connection**.

**Success indicators:**
- ✅ Connection successful message
- ✅ Database list appears
- ✅ No error dialogs

---

## Connection String Formats

### Basic Connection String

```
mongodb://username:password@host:port/database?authSource=admin
```

### With SSL (if enabled)

```
mongodb://username:password@host:port/database?authSource=admin&ssl=true
```

### With Connection Options

```
mongodb://username:password@host:port/database?authSource=admin&ssl=false&directConnection=true&retryWrites=true
```

### Connection String Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `authSource` | Database used for authentication | `admin` |
| `ssl` | Enable/disable SSL | `true` or `false` |
| `directConnection` | Connect directly to specified host | `true` |
| `retryWrites` | Retry write operations | `true` |
| `readPreference` | Read preference mode | `primary` |

---

## Security Best Practices

### 🔒 Essential Security Measures

1. **Strong Passwords**
   - Minimum 16 characters
   - Mix of character types
   - Use password manager

2. **IP Whitelisting**
   - Only allow specific IPs in firewall
   - Remove old/unused rules regularly

3. **Network Binding**
   - Never use `0.0.0.0` in production
   - Bind to specific IPs only

4. **Enable Authentication**
   - Always enable `authorization: enabled`
   - Use role-based access control (RBAC)

5. **Regular Updates**
   ```bash
   sudo apt update && sudo apt upgrade mongodb-org
   ```

6. **Monitor Access Logs**
   ```bash
   sudo tail -f /var/log/mongodb/mongod.log
   ```

### 🛡️ Advanced Security (Optional)

#### Enable SSL/TLS

1. Generate certificates:
```bash
sudo openssl req -newkey rsa:2048 -nodes -keyout /etc/ssl/mongodb.key -x509 -days 365 -out /etc/ssl/mongodb.crt
```

2. Update `mongod.conf`:
```yaml
net:
  ssl:
    mode: requireSSL
    PEMKeyFile: /etc/ssl/mongodb.crt
    PEMKeyPassword: <password>
```

#### Create Application-Specific Users

Instead of using root user, create limited users:

```js
use myapp
db.createUser({
  user: "appuser",
  pwd: "AppPassword123",
  roles: [
    { role: "readWrite", db: "myapp" }
  ]
})
```

#### Use MongoDB Atlas (Cloud Alternative)

For production, consider MongoDB Atlas:
- Built-in security
- Automatic backups
- Monitoring and alerts
- [https://www.mongodb.com/cloud/atlas](https://www.mongodb.com/cloud/atlas)

---

## Troubleshooting

### ❌ Connection Refused

**Symptoms:**
- "Connection refused" error
- Timeout errors

**Solutions:**

1. **Check MongoDB is running:**
   ```bash
   sudo systemctl status mongod
   ```

2. **Verify bindIp configuration:**
   ```bash
   sudo cat /etc/mongod.conf | grep bindIp
   ```

3. **Check firewall rules:**
   ```bash
   sudo ufw status
   ```

4. **Test port accessibility:**
   ```bash
   # From your local PC
   telnet <VPS_IP> 27017
   # or
   nc -zv <VPS_IP> 27017
   ```

5. **Check MongoDB logs:**
   ```bash
   sudo tail -f /var/log/mongodb/mongod.log
   ```

### ❌ Authentication Failed

**Symptoms:**
- "Authentication failed" error
- "Invalid credentials" message

**Solutions:**

1. **Verify user exists:**
   ```bash
   mongosh -u admin -p --authenticationDatabase admin
   ```

2. **Check authentication database:**
   - Ensure `authSource=admin` in connection string

3. **Reset password (if needed):**
   ```js
   use admin
   db.changeUserPassword("admin", "NewPassword123")
   ```

### ❌ Firewall Blocking Connection

**Symptoms:**
- Connection timeout
- "No route to host" error

**Solutions:**

1. **Verify firewall rule:**
   ```bash
   sudo ufw status numbered
   ```

2. **Check if UFW is active:**
   ```bash
   sudo ufw status
   ```

3. **Temporarily disable firewall (testing only):**
   ```bash
   sudo ufw disable
   # Test connection
   # Re-enable: sudo ufw enable
   ```

4. **Check VPS provider firewall:**
   - Some VPS providers have additional firewalls
   - Check VPS control panel for firewall rules

### ❌ Wrong IP Address

**Symptoms:**
- Connection works intermittently
- IP address changed

**Solutions:**

1. **Get current public IP:**
   ```bash
   curl ifconfig.me
   ```

2. **Update firewall rule:**
   ```bash
   sudo ufw delete <old_rule_number>
   sudo ufw allow from <NEW_IP> to any port 27017
   ```

3. **Use dynamic DNS (for changing IPs):**
   - Consider using a service like No-IP or DuckDNS
   - Update firewall to allow from domain

### ❌ MongoDB Service Not Starting

**Symptoms:**
- `systemctl status mongod` shows failed
- Error in logs

**Solutions:**

1. **Check logs:**
   ```bash
   sudo journalctl -u mongod -n 100
   ```

2. **Verify configuration syntax:**
   ```bash
   sudo mongod --config /etc/mongod.conf --test
   ```

3. **Check disk space:**
   ```bash
   df -h
   ```

4. **Check permissions:**
   ```bash
   ls -la /var/lib/mongodb
   ```

### ❌ Port Already in Use

**Symptoms:**
- "Address already in use" error

**Solutions:**

1. **Find process using port:**
   ```bash
   sudo lsof -i :27017
   # or
   sudo netstat -tulpn | grep 27017
   ```

2. **Kill process (if safe):**
   ```bash
   sudo kill <PID>
   ```

---

## Alternative Connection Methods

### Method 1: SSH Tunnel (Most Secure)

Create an SSH tunnel to access MongoDB securely:

```bash
# From your local PC
ssh -L 27017:localhost:27017 root@<VPS_IP>
```

Then connect Compass to:
```
mongodb://admin:StrongPassword123@localhost:27017/admin?authSource=admin
```

**Advantages:**
- No need to expose MongoDB to internet
- Encrypted connection
- No firewall changes needed

### Method 2: VPN Connection

1. Set up VPN server on VPS
2. Connect local PC to VPN
3. Use VPS private IP in connection string

### Method 3: MongoDB Atlas (Cloud)

Use MongoDB's managed cloud service:
- Automatic security
- Built-in backups
- Monitoring and alerts
- [https://www.mongodb.com/cloud/atlas](https://www.mongodb.com/cloud/atlas)

---

## Verification Checklist

Use this checklist to verify your setup:

### VPS Configuration

- [ ] MongoDB is installed and running
- [ ] `/etc/mongod.conf` has correct `bindIp` (not `0.0.0.0`)
- [ ] `security.authorization` is enabled
- [ ] MongoDB service restarted after config changes
- [ ] Admin user created successfully
- [ ] Firewall rule added for your PC's public IP
- [ ] UFW is active and rules are correct

### Local PC

- [ ] MongoDB Compass is installed
- [ ] Know your current public IP address
- [ ] Connection string is correct
- [ ] Credentials are correct

### Connection Test

- [ ] Can connect from MongoDB Compass
- [ ] Can see databases
- [ ] Can perform read operations
- [ ] Can perform write operations (if needed)

### Security

- [ ] Strong password is set
- [ ] Only necessary IPs are whitelisted
- [ ] Authentication is enabled
- [ ] Regular backups are configured (optional)

---

## Quick Reference Commands

### VPS Commands

```bash
# Edit MongoDB config
sudo nano /etc/mongod.conf

# Restart MongoDB
sudo systemctl restart mongod

# Check MongoDB status
sudo systemctl status mongod

# View MongoDB logs
sudo tail -f /var/log/mongodb/mongod.log

# Access MongoDB shell
mongosh

# Check firewall status
sudo ufw status numbered

# Allow IP through firewall
sudo ufw allow from <IP> to any port 27017
```

### MongoDB Shell Commands

```js
// Switch to admin database
use admin

// Create user
db.createUser({
  user: "admin",
  pwd: "password",
  roles: ["root"]
})

// List users
db.getUsers()

// Change password
db.changeUserPassword("admin", "newpassword")

// Exit
exit
```

---

## Additional Resources

- **MongoDB Official Documentation**: [https://docs.mongodb.com/](https://docs.mongodb.com/)
- **MongoDB Compass Guide**: [https://docs.mongodb.com/compass/](https://docs.mongodb.com/compass/)
- **MongoDB Security Checklist**: [https://docs.mongodb.com/manual/administration/security-checklist/](https://docs.mongodb.com/manual/administration/security-checklist/)
- **UFW Firewall Guide**: [https://help.ubuntu.com/community/UFW](https://help.ubuntu.com/community/UFW)

---

## Support

If you encounter issues not covered in this guide:

1. Check MongoDB logs: `sudo journalctl -u mongod -n 100`
2. Verify firewall rules: `sudo ufw status numbered`
3. Test network connectivity: `telnet <VPS_IP> 27017`
4. Review MongoDB documentation
5. Check MongoDB community forums

---

**Last Updated:** 2024
**Version:** 2.0

---

✅ **You're all set! Happy querying!** 🎉
