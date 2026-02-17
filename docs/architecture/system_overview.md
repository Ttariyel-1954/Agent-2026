# ARTI 2026 - Sistem Arxitekturasi

## Umumi Gorunus

```
                    +------------------+
                    |    NGINX (SSL)   |
                    |  Reverse Proxy   |
                    +--------+---------+
                             |
              +--------------+--------------+
              |              |              |
     +--------v---+  +------v------+ +-----v-------+
     | Web Portal |  |Admin Panel  | |Exam Platform|
     | (React.js) |  |(React.js)   | |(React.js)   |
     +--------+---+  +------+------+ +-----+-------+
              |              |              |
              +--------------+--------------+
                             |
                    +--------v---------+
                    |   API Gateway    |
                    |   (FastAPI)      |
                    +--------+---------+
                             |
         +-------------------+-------------------+
         |           |           |               |
   +-----v---+ +----v----+ +----v------+ +------v-----+
   |  Agent  | |Assessmnt| |Certific.  | |School Net. |
   |  Service| |Service  | |Service    | |Service     |
   +---------+ +---------+ +----------+ +------------+
         |           |           |               |
         +-----------+-----------+---------------+
                             |
              +--------------+--------------+
              |              |              |
     +--------v---+  +------v------+ +-----v-------+
     |PostgreSQL  |  |   Redis     | |  MongoDB    |
     |(Ana DB)    |  |(Kesh/Queue) | |(Kontent)    |
     +------------+  +-------------+ +-------------+
```

## Texnoloji Yigin

| Qat | Texnologiya | Meqsed |
|-----|-------------|--------|
| Frontend | React.js + Next.js | Veb interfeys |
| Mobile | React Native | Mobil tetbiq |
| API | FastAPI (Python) | Backend xidmetler |
| AI Agent | LangChain + Anthropic | AI sistemi |
| Ana DB | PostgreSQL 16 | Esas melumatlar |
| Kesh | Redis 7 | Sessiya, kesh |
| Kontent DB | MongoDB 7 | Sual bazasi, kontent |
| Proxy | Nginx | SSL, load balancing |
| Container | Docker + K8s | Deploy |
| Monitoring | Prometheus + Grafana | Izleme |
| CI/CD | GitHub Actions | Avtomatik deploy |

## Microservice Arxitekturasi

Her modul mustaqil xidmet kimi isleyir:

1. **Agent Service** (port 8001) - AI muhurrik
2. **Assessment Service** (port 8002) - CAT/MST
3. **Certification Service** (port 8003) - Imtahanlar
4. **School Network Service** (port 8004) - Mekteb melumatlari

## Tehlukesizlik

- JWT autentifikasiya
- Role-based access control (RBAC)
- SSL/TLS encryption
- Rate limiting
- SQL injection qorumasi
- XSS qorumasi
- CORS konfiqurasiya

## Melumat Axini

1. Mekteb -> API -> Verilener Bazasi
2. Imtahan -> WebSocket -> Real vaxt izleme
3. Agent -> Plugin -> Modul -> Netice
