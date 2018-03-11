Now, let's run some apps.

### 1,2. 1,2. Nginx

First, let's run a webserver with nginx. Which is something very simple to make
sure the cluster works. Run it easily with
`kubectl run nginx --image nginx --port=80`. This creates a deployment which you
can check with `kubectl get deployments` and look for more details/troubleshoot
with `kubectl describe deployment nginx`. Once is running, we can expose it with
a service: `kubectl expose deployment nginx --type=NodePort`. Now to access access the server default page we need to know which node the pod is on, for the IP, and the port.
* For the IP check where the pod is running with `kubectl get pods` and then `kubectl describe pod nginx-7587c6fdb6-qh48h | grep Node`. You should see the node and the IP here;
* For the port run `kubectl get svc` and see under the PORT(S) column.
Finally, you'll end up with something like
`curl 10.0.0.20:31290` which should give you something like:
```html
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...
```

Now, to clean up, delete the deployment and the service:
```bash
kubectl delete deployment nginx
kubectl delete svc nginx
```
