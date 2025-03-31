(ns open-library.server
  (:require [ring.adapter.jetty :as jetty] :reload
            [open-library.controller.router :as router]))

(defn -main
  [& args]
  (jetty/run-jetty router/app {:port 3000}))
