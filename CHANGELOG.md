## v1.4.0 (2025-09-04)

### feat

- Replace NGINX WAF with Traefik + ModSecurity and implement Redis Sentinel HA

## v1.3.0 (2025-09-04)

### feat

- replace NGINX WAF with Traefik + ModSecurity container & fix deployment issues
- migrate from NGINX WAF to Traefik with security middleware

### fix

- add DNS resolver and correct service name for nginx-waf
- please bump

## v1.2.10 (2025-09-02)

### fix

- change nginx-waf to replicated mode and improve placement strategy

## v1.2.9 (2025-09-02)

### fix

- correct backend service name in nginx-waf configuration

## v1.2.8 (2025-09-02)

### fix

- limit_req off; removed

## v1.2.7 (2025-09-02)

### fix

-  modsecurity from ModSecurityEnabled

## v1.2.6 (2025-09-02)

### fix

- modsecurity off directive was wrong

## v1.2.5 (2025-09-02)

### fix

- ModSecurityEnabled off; assignsment

## v1.2.4 (2025-09-02)

### fix

- rate limits

## v1.2.3 (2025-09-02)

### fix

- Correct directive placement and enable WebSockets

## v1.2.12 (2025-09-02)

### fix

- add DNS resolver and correct service name for nginx-waf

## v1.2.11 (2025-09-02)

### fix

- please bump

## v1.2.10 (2025-09-02)

### fix

- change nginx-waf to replicated mode and improve placement strategy

## v1.2.9 (2025-09-02)

### fix

- correct backend service name in nginx-waf configuration

## v1.2.8 (2025-09-02)

### fix

- limit_req off; removed

## v1.2.7 (2025-09-02)

### fix

-  modsecurity from ModSecurityEnabled

## v1.2.6 (2025-09-02)

### fix

- modsecurity off directive was wrong

## v1.2.5 (2025-09-02)

### fix

- ModSecurityEnabled off; assignsment

## v1.2.4 (2025-09-02)

### fix

- rate limits

## v1.2.3 (2025-09-02)

### fix

- Correct directive placement and enable WebSockets

## v1.2.2 (2025-09-02)

### fix

- align load balancer and firewall configuration with WAF port 8080
- update OWASP ModSecurity container port configuration

## v1.2.1 (2025-09-02)

### fix

- add proper bounds checking for Authorization header token extraction

## v1.2.0 (2025-09-02)

### feat

- implement OWASP ModSecurity CRS with proper configuration

## v1.1.4 (2025-09-02)

### fix

- disable OWASP CRS by default - files not available in container

## v1.1.3 (2025-09-02)

### fix

- disable unicode mapping in ModSecurity configuration

## v1.1.2 (2025-09-02)

### fix

- escape Docker Compose variable interpolation in Redis command

## v1.1.1 (2025-09-02)

### fix

- resolve nginx PID permissions and enhance container security

## v1.1.0 (2025-09-02)

### feat

- enhance container security with comprehensive tmpfs configuration

## v1.0.1 (2025-09-02)

### chore

- deleted change log

## v1.0.0 (2025-09-02)

### feat

- bump to version 1.0.0 with enhanced security

### fix

- trigger bump
