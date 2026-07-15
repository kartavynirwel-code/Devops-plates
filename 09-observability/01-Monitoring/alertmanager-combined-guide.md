# Alertmanager — Email Alerts Complete Setup (Easy Guide)

Is guide me Alertmanager se **email notification** bhejna seekhenge — step by
step, simple bhasha me. Pehle samjhenge concept, phir code, phir test karna.

---

## 1. Alertmanager kya karta hai? (Concept — pehle ye samjho)

```
Prometheus     → metrics collect karta hai, condition check karta hai
                  (e.g. "CPU 50% se zyada hai?") → agar haan, ALERT fire karta hai

Alertmanager   → us alert ko receive karta hai aur decide karta hai:
                  1. Kisko bhejna hai      (routing)
                  2. Kaise bhejna hai       (email/Slack/PagerDuty)
                  3. Kab bhejna hai         (grouping — turant ya wait karke)
                  4. Duplicate/related alerts kaise chup karayein (inhibition)
```

**Real life example:** Ek node down ho jaaye, toh usme chal rahe 10 pods ki
bhi alerts fire hongi. Bina Alertmanager ke tumhe 11 alerts milengi. Alertmanager
inhe samajhdaari se group/suppress karke sirf zaroori notification bhejta hai.

---

## 2. Kya banayenge — 3 files

```
alerts.yml               → PrometheusRule: kis condition pe alert fire ho
email-secrets.yml        → Secret: Gmail app password (base64 encoded)
alertmanagerconfig.yml   → AlertmanagerConfig: email kisko/kaise/kab jaaye
```

Teeno `monitoring` namespace me jaayenge (jahan `kube-prometheus-stack` installed hai).

---

## 3. Step 1: Gmail App Password banao

Normal Gmail password kaam **nahi** karega — Alertmanager ko "App Password" chahiye.

1. Google Account → **Security** → **2-Step Verification** ON karo
2. Security me **"App passwords"** search karo
3. App ka naam do (e.g. `alertmanager`) → **Generate**
4. 16-character password milega — spaces hata ke copy karo

```bash
# Is password ko base64 encode karo (Kubernetes Secret isi format me chahta hai)
echo -n "your16charapppassword" | base64
```

Output ko copy kar lo — Step 5 me use hoga.

---

## 4. Step 2: `email-secrets.yml` — password store karna

```yaml
apiVersion: v1
kind: Secret
type: Opaque
metadata:
  name: mail-pass
  namespace: monitoring
  labels:
    release: monitoring    # ⚠️ helm release ka naam yahi hona chahiye, warna Alertmanager isse ignore kar dega
data:
  gmail-pass: <<BASE64_ENCODED_APP_PASSWORD>>   # yahan wo base64 wala output paste karo
```

**Simple samjho:** Ye ek locked box hai jisme password safely store hota hai.
Password ko seedha config file me likhna bad practice hai — isliye Secret use karte hain.

---

## 5. Step 3: `alerts.yml` — kab alert fire ho

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: custom-alert-rules
  namespace: monitoring
  labels:
    release: monitoring
spec:
  groups:
  - name: custom.rules
    rules:

    # ── CPU zyada use ho rahi hai ──────────────────────────
    - alert: HighCpuUsage
      expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[2m])) * 100) > 50
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High CPU usage on instance {{ $labels.instance }}"
        description: "CPU usage {{ $value | printf \"%.2f\" }}% hai instance {{ $labels.instance }} par, 5 min se zyada."

    # ── Pod baar-baar restart ho raha hai (crash-loop) ─────
    - alert: PodRestart
      expr: kube_pod_container_status_restarts_total > 2
      for: 0m
      labels:
        severity: critical
      annotations:
        summary: "Pod {{ $labels.pod }} restart hua namespace {{ $labels.namespace }} me"
        description: "Container {{ $labels.container }}, pod {{ $labels.pod }} (namespace: {{ $labels.namespace }}) {{ $value }} baar restart hua hai."

    # ── Pod memory limit ke close hai ──────────────────────
    - alert: HighMemoryUsage
      expr: (container_memory_usage_bytes{container!="", pod!=""} / container_spec_memory_limit_bytes{container!="", pod!=""}) * 100 > 80
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Pod {{ $labels.pod }} ka memory usage high hai (namespace: {{ $labels.namespace }})"
        description: "Pod {{ $labels.pod }}, container {{ $labels.container }} apni memory limit ka {{ $value | printf \"%.2f\" }}% use kar raha hai, 5+ min se."

    # ── Pod down/crash ho gaya ──────────────────────────────
    - alert: PodDown
      expr: kube_pod_status_phase{phase=~"Failed|Unknown"} > 0
      for: 2m
      labels:
        severity: critical
      annotations:
        summary: "Pod {{ $labels.pod }} down hai (namespace: {{ $labels.namespace }})"
        description: "Pod {{ $labels.pod }}, namespace {{ $labels.namespace }} me {{ $labels.phase }} state me hai, 2+ min se."
```

**Simple samjho — har alert ke 4 parts:**

| Part | Matlab |
|---|---|
| `expr` | Konsi condition check ho rahi hai (PromQL query) |
| `for` | Ye condition kitni der true rahe tabhi alert fire ho (false alarm rokta hai) |
| `severity` label | `warning` ya `critical` — isi se decide hoga routing me kya priority milegi |
| `annotations` | Alert ka **message** — yahi email me dikhega. `{{ $labels.pod }}` isliye likha hai taaki pata chale **kis pod** me problem hai |

---

## 6. Step 4: `alertmanagerconfig.yml` — email kisko/kab/kaise jaaye

```yaml
apiVersion: monitoring.coreos.com/v1alpha1
kind: AlertmanagerConfig
metadata:
  name: main-rules-alert-config
  namespace: monitoring
  labels:
    release: monitoring
spec:
  route:
    repeatInterval: 30m       # default: same alert dobara 30 min baad hi bhejo
    receiver: 'null'          # koi route match na ho toh silently ignore (spam nahi)
    routes:

    - matchers:
      - name: alertname
        value: HighCpuUsage
      receiver: 'send-email'

    - matchers:
      - name: alertname
        value: PodRestart
      receiver: 'send-email'
      repeatInterval: 5m      # critical hai isliye jaldi-jaldi bhejo

    - matchers:
      - name: alertname
        value: HighMemoryUsage
      receiver: 'send-email'

    - matchers:
      - name: alertname
        value: PodDown
      receiver: 'send-email'
      repeatInterval: 5m

  # ── INHIBITION — noise kam karne ka trick ──────────────────
  # Agar PodDown (critical) already fire ho chuka hai, toh usi pod ki
  # HighMemoryUsage (warning) wali alert ko chup kara do — kyunki wo
  # pod already down hai, memory alert bekar/redundant hai.
  inhibitRules:
  - sourceMatch:
    - name: alertname
      value: PodDown
    targetMatch:
    - name: alertname
      value: HighMemoryUsage
    equal: ['pod', 'namespace']

  receivers:
  - name: 'send-email'
    emailConfigs:
    - to: YOUR_EMAIL_ID@gmail.com
      from: YOUR_EMAIL_ID@gmail.com
      sendResolved: true        # problem fix hone par ek "Resolved" email bhi aayegi
      smarthost: smtp.gmail.com:587
      authUsername: YOUR_EMAIL_ID@gmail.com
      authIdentity: YOUR_EMAIL_ID@gmail.com
      authPassword:
        name: mail-pass         # Step 2 wale Secret ka naam
        key: gmail-pass         # usi Secret ki key
      headers:
      - key: Subject
        value: "🚨 Alert: {{ .CommonLabels.alertname }} on pod {{ .CommonLabels.pod }}"
      html: |
        <h3>{{ .CommonAnnotations.summary }}</h3>
        <p>{{ .CommonAnnotations.description }}</p>
        <p><b>Severity:</b> {{ .CommonLabels.severity }}</p>
        <p><b>Namespace:</b> {{ .CommonLabels.namespace }}</p>
        <p><b>Pod:</b> {{ .CommonLabels.pod }}</p>
  - name: 'null'
```

> ⚠️ `YOUR_EMAIL_ID@gmail.com` ko apne actual email se replace karo — **3 jagah** (`to`, `from`, `authUsername`/`authIdentity`).

**Simple samjho:**

| Concept | Matlab |
|---|---|
| `routes` | Kaunsa alert kisko jaaye — yahan sab `send-email` receiver ko jaa rahe hain |
| `repeatInterval` | Kitni der baad same alert dobara bheju agar problem solve nahi hui |
| `inhibitRules` | Bade problem (PodDown) ke saamne chhote related alert (HighMemoryUsage) ko chup kara do — same pod ho toh |
| `receivers` | Actual "kaise bhejna hai" ka detail — yahan Gmail SMTP |
| Email `headers`/`html` | Subject aur body customize kiya hai taaki **pod ka naam seedha dikhe**, generic message na ho |

---

## 7. Apply karo

```bash
kubectl create ns monitoring   # agar pehle se nahi bana

kubectl apply -f alerts.yml
kubectl apply -f email-secrets.yml
kubectl apply -f alertmanagerconfig.yml
```

Verify karo sab ban gaya:

```bash
kubectl get prometheusrule -n monitoring
kubectl get secret mail-pass -n monitoring
kubectl get alertmanagerconfig -n monitoring
```

---

## 8. Config validate karo (apply se pehle galti pakadna)

Bada mistake: seedha apply kar dena aur baad me error milna. Isse bacho:

```bash
# amtool install karo (agar nahi hai)
# amtool prometheus-community releases se milta hai

amtool check-config alertmanagerconfig.yml
```

Ye YAML indentation ya missing field jaisi galti apply karne se pehle hi bata dega.

---

## 9. Config reload verify karo

Secret/config apply karne ke baad Alertmanager khud reload kar leta hai (~1 min me):

```bash
kubectl logs -n monitoring <alertmanager-pod-name> -c config-reloader

# ya UI se seedha dekho
kubectl port-forward svc/prometheus-kube-prometheus-alertmanager 9093:9093 -n monitoring
# Browser: http://localhost:9093/#/status → "Config" tab me apna latest YAML dikhega
```

Reload na ho toh manual restart karo:
```bash
kubectl rollout restart statefulset alertmanager-prometheus-kube-prometheus-alertmanager -n monitoring
```

---

## 10. Test karo — bina real problem wait kiye

**Option A — Real crash karke:**
```bash
kubectl delete pod <pod-name> -n <namespace> --grace-period=0 --force
```

**Option B — Fake alert seedha bhej ke (fastest way):**
```bash
kubectl port-forward svc/prometheus-kube-prometheus-alertmanager 9093:9093 -n monitoring

curl -H "Content-Type: application/json" -d '[{
  "labels": {"alertname": "PodRestart", "severity": "critical",
             "pod": "test-pod", "namespace": "monitoring", "container": "test"},
  "annotations": {"summary": "Test alert", "description": "Testing email setup"}
}]' http://localhost:9093/api/v2/alerts
```

5-10 second me email inbox check karo.

---

## 11. Maintenance ke waqt alert silence karna

Jab planned downtime ho aur email spam na chahiye:

```bash
# UI se: http://localhost:9093 → "New Silence" button

# Ya amtool se
amtool silence add alertname="PodDown" namespace="monitoring" \
  --duration="2h" \
  --comment="Planned maintenance"
```

---

## 12. Ye setup kya bhejta hai — summary table

| Alert | Kab fire ho | Severity | Email me kya dikhega |
|---|---|---|---|
| `HighCpuUsage` | CPU 50%+, 5 min tak | warning | Instance name + CPU % |
| `PodRestart` | Container 2+ baar restart | critical | **Pod name**, container, namespace, restart count |
| `HighMemoryUsage` | Memory limit ka 80%+, 5 min tak | warning | **Pod name**, container, namespace, usage % |
| `PodDown` | Pod Failed/Unknown, 2+ min | critical | **Pod name**, namespace, phase |

---

## ⚠️ Gotchas (sab combine karke)

1. **`release: monitoring` label** — teeno files me zaroori hai, warna Prometheus/Alertmanager ignore kar dega.
2. **Gmail App Password hi chalega** — normal password reject ho jaayega.
3. **Secret ka base64 encode zaroori** — plain text daaloge toh Kubernetes error dega.
4. **`sendResolved: true`** — isse tumhe pata chalega jab problem apne aap fix ho jaaye.
5. **AlertmanagerConfig namespace-scoped CRD hai** — agar Alertmanager CR ka `alertmanagerConfigSelector` set nahi hai helm values me, config pick hi nahi hoga (`helm get values monitoring -n monitoring` check karo).
6. **Inhibition rule na ho** → same problem ke liye multiple emails aayenge — noisy inbox.
7. **`amtool check-config` skip mat karo** — apply karne se pehle hi galti pakad leta hai.

---

## Interview Questions

**Q: Alertmanager Prometheus se alag kyun hai?**
> Prometheus sirf condition check karke alert *fire* karta hai. Alertmanager
> routing, grouping, deduplication, aur actual notification (email/Slack/PagerDuty)
> handle karta hai — separation of concerns.

**Q: Inhibition rule ka kaam kya hai?**
> Jab ek bade problem (PodDown) ki wajah se related chhoti alerts (jaise
> HighMemoryUsage) bhi fire ho jaayein, inhibition unhe suppress karke sirf
> root-cause wali alert dikhata hai — inbox clean rehta hai.

**Q: Alert message me pod name kaise dikhta hai?**
> PromQL query jo labels return karti hai (jaise `pod`, `namespace`), unhe
> annotation ke andar `{{ $labels.pod }}` syntax se access karte hain —
> ye Prometheus template language hai.
