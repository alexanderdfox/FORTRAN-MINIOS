# Security Guide - Superbook MMO

## 🔒 Security Best Practices

### Environment Variables

**Never commit secrets to version control!**

1. **Always use `.env` file** (already in `.gitignore`)
   ```bash
   # Copy template
   cp .env.example .env
   
   # Edit with real values
   nano .env
   ```

2. **Generate strong secret keys**
   ```bash
   # Generate SECRET_KEY
   python3 -c "import secrets; print(secrets.token_hex(32))"
   ```

3. **Rotate keys regularly** in production

### Docker Security

#### Docker Hub Credentials

For private images:

1. **Use Docker secrets:**
   ```bash
   # Create secrets file (NOT in git)
   cat > ~/.docker-secrets << EOF
   DOCKER_USERNAME=your_username
   DOCKER_PASSWORD=your_password
   EOF
   
   # Use with docker-compose
   docker-compose --env-file ~/.docker-secrets up
   ```

2. **Or use environment variables:**
   ```bash
   export DOCKER_USERNAME=your_username
   export DOCKER_PASSWORD=your_password
   docker-compose up
   ```

3. **Or Docker login:**
   ```bash
   docker login
   # Store in ~/.docker/config.json
   ```

#### Docker Image Security

✅ **Already configured:**
- Non-root user in container
- Minimal base image (Python slim)
- Health checks
- Security options in docker-secrets.yml
- Capability dropping
- No new privileges

#### Build Args for Private Images

Edit `Dockerfile` to use private registries:

```dockerfile
# Add build args
ARG DOCKER_USERNAME
ARG DOCKER_PASSWORD

# For private base images
FROM --platform=$BUILDPLATFORM $DOCKER_USERNAME/python:3.11-slim
```

Use:
```bash
docker build \
  --build-arg DOCKER_USERNAME=your_user \
  --build-arg DOCKER_PASSWORD=your_pass \
  -t superbook-mmo .
```

### API Keys

#### OpenAI API Key

✅ **Secure methods:**

1. **Environment file** (recommended)
   ```bash
   echo "OPENAI_API_KEY=sk-..." > .env
   docker-compose up
   ```

2. **Docker secrets**
   ```bash
   echo "sk-..." | docker secret create openai_key -
   ```

3. **Secret management tools**
   - AWS Secrets Manager
   - HashiCorp Vault
   - Google Secret Manager
   - Azure Key Vault

### File Permissions

```bash
# Secure .env file
chmod 600 .env

# Secure data directory
chmod 700 data/

# Secure logs
chmod 755 logs/
```

### Production Deployment

#### 1. HTTPS/SSL

Use reverse proxy (nginx/Traefik) with SSL:

```nginx
server {
    listen 443 ssl http2;
    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;
    
    location / {
        proxy_pass http://localhost:8000;
    }
}
```

#### 2. Firewall

```bash
# Allow only necessary ports
sudo ufw allow 22/tcp   # SSH
sudo ufw allow 443/tcp  # HTTPS
sudo ufw enable
```

#### 3. Network Security

```bash
# Use private networks in docker-compose
networks:
  internal:
    internal: true
```

#### 4. Regular Updates

```bash
# Update base images
docker-compose pull
docker-compose up -d --build

# Update dependencies
pip install --upgrade -r requirements.txt
```

### Security Checklist

#### Pre-Deployment

- [ ] `.env` in `.gitignore` ✓
- [ ] Strong `SECRET_KEY` generated ✓
- [ ] API keys secured ✓
- [ ] Database not exposed ✓
- [ ] Non-root user in container ✓
- [ ] Health checks configured ✓
- [ ] Firewall rules set ✓
- [ ] HTTPS enabled ✓
- [ ] Logging configured ✓
- [ ] Backup strategy planned ✓

#### Runtime

- [ ] Environment variables loaded
- [ ] Secrets management in place
- [ ] Network isolation configured
- [ ] Access logs monitored
- [ ] Regular security updates
- [ ] Incident response plan

### Monitoring

#### Log Monitoring

```bash
# Check for errors
docker-compose logs | grep -i error

# Monitor access
docker-compose logs -f | grep "GET\|POST"
```

#### Security Audits

```bash
# Scan image for vulnerabilities
docker scan superbook-mmo

# Check for exposed secrets
docker-compose config | grep -i secret
docker-compose config | grep -i key
```

### Backup & Recovery

#### Data Backup

```bash
# Backup database
tar -czf backup-$(date +%Y%m%d).tar.gz data/

# Encrypt backup
gpg -c backup-$(date +%Y%m%d).tar.gz
```

#### Recovery

```bash
# Restore from backup
tar -xzf backup-YYYYMMDD.tar.gz -C data/

# Verify integrity
sha256sum data/crawler_database.db
```

### Incident Response

If security breach suspected:

1. **Isolate** - Stop containers
2. **Investigate** - Check logs
3. **Rotate** - Change all keys
4. **Document** - Log incident
5. **Update** - Patch vulnerabilities
6. **Notify** - Alert stakeholders

### Compliance

#### GDPR

- [ ] Data encryption at rest
- [ ] Data encryption in transit
- [ ] User consent mechanism
- [ ] Right to deletion
- [ ] Privacy policy
- [ ] Data retention policy

#### OWASP Top 10

Current protections:
- ✅ SQL injection (SQLAlchemy ORM)
- ✅ XSS (Flask auto-escaping)
- ✅ CSRF (Flask-Session)
- ✅ Broken auth (Flask-Login, bcrypt)
- ✅ Security misconfig (hardened containers)
- ✅ Sensitive data exposure (.env, secrets)
- ⚠️ Rate limiting (add if needed)
- ✅ Insecure deserialization (validated)
- ✅ Inadequate monitoring (implement)
- ⚠️ SSRF (validate inputs)

### Additional Resources

- [OWASP Cheat Sheets](https://cheatsheetseries.owasp.org/)
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [Flask Security](https://flask.palletsprojects.com/en/security/)
- [Python Security](https://python-security.readthedocs.io/)

---

**Remember: Security is an ongoing process, not a one-time setup!**

Regular audits and updates are essential.

🔒 **Keep your Docker keys safe!** 🔒

