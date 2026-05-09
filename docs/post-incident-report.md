# Incident Investigation Runbook
## Capstone Project - DevOps AI Training

---

## 1. Incident Overview
- **Date:** 2024-01-15
- **Severity:** High
- **Affected Services:** All microservices
- **Reported By:** Grafana ML Anomaly Detection

---

## 2. Timeline of Events
| Time | Event | Action Taken |
|------|-------|--------------|
| 10:00 | Normal operation | None |
| 10:01 | CPU spike detected by Grafana | Alert fired |
| 10:02 | Log analysis triggered | analyse.py executed |
| 10:03 | Root cause identified | Connection errors to DB |
| 10:04 | Remediation triggered | rollback.sh executed |
| 10:05 | Service restored | Health check confirmed |

---

## 3. Root Cause Analysis
- **Primary Cause:** Database connection failures causing cascading errors
- **Contributing Factors:**
  - High CPU load from connection retry loops
  - Memory exhaustion from failed connection objects
  - No circuit breaker in place

---

## 4. Impact Assessment
- **Duration:** 5 minutes
- **Services Affected:** sample-app, prometheus scraping
- **Business Impact:** Monitoring data gap during incident window

---

## 5. Resolution Steps
1. Grafana ML detected CPU anomaly above 70%
2. Alert fired to webhook contact point
3. Log analysis script identified connection errors as root cause
4. Health check script confirmed affected containers
5. Rollback script restarted affected service
6. Health checks confirmed service recovery

---

## 6. Action Items
| Action | Owner | Due Date |
|--------|-------|----------|
| Add circuit breaker to DB connections | Dev Team | 1 week |
| Set up log rotation | DevOps | 3 days |
| Configure email alerts | DevOps | 2 days |
| Add DB health check to monitoring | DevOps | 1 week |

---

## 7. Prevention Measures
- Implement multi-window burn rate alerts
- Add database connection pool monitoring
- Set up automated rollback on error rate spike
- Configure Grafana ML with longer training window

---

## 8. Tools Used
- **Detection:** Grafana ML anomaly detection
- **Analysis:** Python log analysis script (analyse.py)
- **Diagnostics:** Bash health check script (health-check.sh)
- **AI Assistance:** GitHub Copilot (VS Code)
- **Documentation:** This runbook
