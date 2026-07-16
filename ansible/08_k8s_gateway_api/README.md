# 🚪 Escenario 08: Gateway API (Cilium + Canary)

Este laboratorio despliega un clúster de Kubernetes HA de **6 nodos** (idéntico al escenario 02: 3 managers + 3 workers, kube-vip), usando **Cilium** como CNI y como implementación de **Gateway API** — a diferencia del resto de laboratorios de red (06: MetalLB + NGINX Ingress), aquí Cilium sustituye tanto a Flannel (CNI) como a un LoadBalancer/Gateway externo, ya que implementa ambas capacidades de forma nativa en su propio agente. El laboratorio demuestra dos tipos de ruta de Gateway API:

*   **`HTTPRoute`** — dos versiones de una misma app (`stable`/`canary`) con reparto de tráfico ponderado (80/20), para demostrar un despliegue Canary.
*   **`GRPCRoute`** — un servicio gRPC de ejemplo, para demostrar el enrutamiento nativo de gRPC (imposible con un `Ingress` clásico).

## 📋 Estructura de Playbooks

*   **`02_crear_nodos.yml`** a **`05_instalar_k8s_tools.yml`**: reutilizan (`import_playbook`) los playbooks del escenario 02 para crear las 6 VMs, configurar el SO e instalar containerd/kubeadm/kubelet/kubectl.
*   **`06_inicializar_primer_manager.yml`**: **no** se reutiliza el del escenario 02 (que instala Flannel) — este archivo es propio del escenario 08: inicializa kubeadm igual, instala las CRDs de Gateway API (canal `experimental`, con `--server-side` — ver nota más abajo) requeridas por Cilium de antemano, elimina el `DaemonSet`/`ConfigMap` `kube-proxy` (Cilium lo sustituye por completo) y, en vez de Flannel, instala **Cilium** vía Helm con `kubeProxyReplacement: true`, `gatewayAPI.enabled: true` y `l2announcements.enabled: true`.
*   **`07_unir_managers.yml`** y **`08_unir_workers.yml`**: reutilizan (`import_playbook`) los del escenario 02 sin cambios (no dependen del CNI).
*   **`09_desplegar_headlamp.yml`**: despliega Headlamp Dashboard (NodePort, igual que en el resto de laboratorios) **justo después de formar el clúster**, antes que ningún otro componente — así se puede seguir desde la consola web el resto de los despliegues (Cilium LB, Gateway API, apps demo, gRPC) a medida que se ejecutan.
*   **`10_configurar_cilium_lb.yml`**: crea el `CiliumLoadBalancerIPPool` (rango de IPs) y la `CiliumL2AnnouncementPolicy` (anuncio ARP), el equivalente nativo de Cilium a `IPAddressPool`/`L2Advertisement` de MetalLB.
*   **`11_desplegar_gateway_api.yml`**: crea la `GatewayClass` (`cilium`, controlador `io.cilium/gateway-controller`) y **dos** objetos `Gateway` separados — `demo-gateway-http` (puerto 80, `HTTPRoute`) y `demo-gateway-grpc` (puerto 8080, `GRPCRoute`, host `grpc.gw.local`) — en vez de uno solo con varios listeners (ver nota más abajo). Cilium crea automáticamente un `Service` `LoadBalancer` por cada uno (`cilium-gateway-demo-gateway-http`/`-grpc`) en el namespace `default`.
*   **`12_desplegar_apps_canary.yml`**: despliega dos Deployments/Services (`demo-stable` y `demo-canary`) y un `HTTPRoute` que reparte el tráfico 80%/20% entre ambos mediante `backendRefs[].weight`.
*   **`13_verificar_canary.yml`**: lanza 100 peticiones HTTP contra la IP del Gateway HTTP y comprueba que ambas versiones han recibido tráfico.
*   **`14_desplegar_grpc.yml`**: despliega `kong/grpcbin` (el equivalente a *httpbin* pero para gRPC, con el servicio `hello.HelloService`) y lo expone a través del Gateway gRPC mediante un `GRPCRoute`. El `Service` marca su puerto con `appProtocol: kubernetes.io/h2c`, imprescindible para que Cilium hable HTTP/2 en texto plano con el backend.
*   **`15_verificar_grpc.yml`**: realiza una llamada gRPC real (`grpcurl`) contra el servicio de ejemplo a través del Gateway gRPC.
*   **`20_destroy.yml`**: destrucción completa del entorno.

No se incluyen playbooks de escalado (`add_node`/`eliminar_nodo`): el escalado de nodos ya está cubierto en los escenarios 02-06, y el foco pedagógico de este laboratorio es el enrutamiento de Gateway API, no la gestión de nodos.

---

## 🚀 Despliegue

```bash
cd 08_k8s_gateway_api
chmod +x run_all.sh destroy_all.sh
./run_all.sh
```

### Acceso:
*   🔗 **HTTP Canary:** IP del Gateway HTTP asignada por el LB-IPAM de Cilium (mostrada al final de `run_all.sh`). Requiere cabecera `Host: gw.local` (o el valor de `gateway_base_domain`), ya que el `HTTPRoute` enruta por nombre de host:
    ```bash
    curl -H "Host: gw.local" http://<IP-DEL-GATEWAY-HTTP>/
    ```
    Ejecútalo varias veces: aproximadamente el 80% de las respuestas serán `version=stable` y el 20% `version=canary`.
*   🔗 **gRPC:** IP del Gateway gRPC (distinta de la del Gateway HTTP), requiere `grpcurl` instalado localmente:
    ```bash
    grpcurl -plaintext -authority grpc.gw.local -d '{"greeting":"mundo"}' <IP-DEL-GATEWAY-GRPC>:8080 hello.HelloService/SayHello
    ```
*   🔗 **Headlamp:** `http://10.207.154.49:32082` — token en `headlamp_token.txt`.

### Destruir el Entorno:
```bash
./destroy_all.sh
```

---

## 📐 Decisiones de Diseño

*   **Cilium como CNI y como implementación de Gateway API:** a diferencia de Envoy Gateway, NGINX Gateway Fabric o Istio (controladores separados que se instalan *sobre* un CNI ya existente), el soporte de Gateway API de Cilium está integrado en su propio agente eBPF — por eso aquí Cilium sustituye a Flannel como CNI del clúster, no se añade como una pieza más.
*   **LB-IPAM + L2Announcement nativos de Cilium en vez de MetalLB:** con Cilium ya presente como CNI, tiene sentido usar su propio IPAM/L2 para los `Service` `LoadBalancer` en vez de instalar MetalLB por separado — evita tener dos componentes compitiendo por el mismo rol de anuncio ARP en la red `lxdbr0`.
*   **CRDs de Gateway API instaladas manualmente ANTES de Cilium (a diferencia del laboratorio con Envoy Gateway):** el chart de Cilium no incluye las CRDs de Gateway API (a diferencia del de Envoy Gateway, que sí las empaqueta); la propia documentación de Cilium exige instalarlas primero para que el operador detecte el `GatewayClass`/`Gateway` desde el arranque.
*   **`kubeProxyReplacement: true` y eliminación del `DaemonSet` `kube-proxy`:** el soporte de Gateway API de Cilium necesita programar él mismo el enrutamiento de los `Service` (vía eBPF) en vez de depender de las reglas `iptables` de kube-proxy — sin esto, la `GatewayClass`/`Gateway` se quedan indefinidamente en estado `Pending` ("Waiting for controller"). Se elimina `kube-proxy` justo antes de instalar Cilium, antes de que se una ningún otro nodo, para que ninguno llegue a tener sus propias reglas `iptables` de kube-proxy.
*   **`k8sServiceHost`/`k8sServicePort` apuntando a la VIP de kube-vip:** al reemplazar a kube-proxy, Cilium ya no puede resolver el `Service` interno `kubernetes.default` vía `iptables` para alcanzar el API server — necesita conocer su dirección de forma directa desde el arranque del agente, y apuntarlo a la VIP (en vez de a la IP de un manager concreto) mantiene la alta disponibilidad.
*   **Versión de las CRDs de Gateway API ligada a la versión de Cilium, no "la más reciente":** se instala la versión de Gateway API (`v1.4.1`) que la propia documentación de la versión de Cilium usada (`1.19.5`) declara como probada — instalar una versión más nueva de las CRDs (p. ej. v1.6.x) puede introducir cambios de esquema en campos como `GatewayClass.status.supportedFeatures` que el operador de una versión de Cilium más antigua no sabe interpretar, dejando la `GatewayClass`/`Gateway` en estado de error silencioso.
*   **`kubectl apply --server-side` para las CRDs de Gateway API:** el esquema de `HTTPRoute` es tan grande que la anotación `kubectl.kubernetes.io/last-applied-configuration` que usa el *client-side apply* por defecto supera el límite de 262144 bytes de Kubernetes — el propio proyecto Gateway API recomienda `--server-side` para instalar sus CRDs por este motivo.
*   **Reparto de tráfico vía `HTTPRoute.spec.rules[].backendRefs[].weight`:** es el mecanismo estándar de Gateway API para Canary/Blue-Green, sin necesitar anotaciones específicas de un Ingress Controller (como las de NGINX Ingress) ni un service mesh completo — demuestra una de las ventajas principales de Gateway API frente al Ingress clásico.
*   **Verificación estadística del reparto (`13_verificar_canary.yml`):** con una muestra de 100 peticiones se comprueba que ambas versiones reciben tráfico, sin exigir una proporción exacta 80/20 (variación estadística normal en una muestra de ese tamaño).
*   **Headlamp desplegado nada más formar el clúster, antes que Cilium LB/Gateway API/apps demo:** a diferencia del resto de laboratorios (donde Headlamp va al final), aquí se adelanta para poder observar desde su consola web cómo se van creando el resto de recursos (Pods, Services, Gateway, HTTPRoute/GRPCRoute...) en tiempo real durante el resto del despliegue.
*   **Sin playbooks de escalado:** siguiendo el mismo criterio aplicado en el escenario 07, el escalado de nodos ya está cubierto en escenarios anteriores y no aporta valor pedagógico adicional aquí.
*   **Dos `Gateway` separados (uno por protocolo) en vez de uno con varios listeners:** Cilium tiene un bug conocido por el que, con varios listeners de distintos `allowedRoutes.kinds` en el mismo `Gateway`, a veces valida una ruta contra el listener equivocado y la rechaza (`NotAllowedByListeners`) aunque el `sectionName` sea correcto. Separar en `demo-gateway-http` y `demo-gateway-grpc` evita el bug por completo sin dejar de ser Gateway API válido (nada obliga a usar un único `Gateway`).
*   **Sin ejemplo de base de datos vía `TCPRoute`:** Cilium todavía no implementa `TCPRoute`/`UDPRoute` en su dataplane (issues abiertos en su repositorio de GitHub) — configurar un listener `TCPRoute` en el `Gateway` no falla, pero el tráfico nunca llegaría al backend. Otras implementaciones de Gateway API (Envoy Gateway, Traefik, HAProxy Ingress) sí soportan `TCPRoute`, pero mezclar dos controladores de Gateway API distintos en el mismo clúster para un único ejemplo no compensaba la complejidad — se prescinde de esa pieza en la variante Cilium de este laboratorio.
*   **`kong/grpcbin` como servicio gRPC de ejemplo:** primer intento con la imagen de ejemplo de Google/GKE (`grpc-hostname`), pero el tag no se resolvía (la imagen ya no existe en ese registro); `kong/grpcbin` es un servidor gRPC de pruebas público y mantenido (el equivalente a *httpbin* para gRPC, con reflection habilitado), sin necesitar compilar nada.
*   **`appProtocol: kubernetes.io/h2c` en el `Service` gRPC:** sin esta anotación, Cilium no sabe que debe hablar HTTP/2 en texto plano (sin TLS) con el backend, y el `GRPCRoute` fallaría silenciosamente.
