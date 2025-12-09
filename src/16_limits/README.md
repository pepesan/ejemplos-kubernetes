## LimitRange
Un LimitRange es un objeto de Kubernetes que define:

Límites máximos de recursos por contenedor o pod

Límites mínimos

Valores por defecto si el usuario no especifica recursos

Ratios permitidos entre requests y limits

Se aplica a nivel de namespace, pero afecta a cada pod o contenedor individual que se ejecute dentro de ese namespace

## ResourceQuota
Un ResourceQuota limita el conjunto total de recursos que puede consumir un namespace completo.

Mientras que el LimitRange regula cada pod, el ResourceQuota regula la suma de todos los pods y objetos del namespace.
