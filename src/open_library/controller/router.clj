(ns open-library.controller.router
  (:require [open-library.controller.wrapper :refer :all]
            [open-library.controller.handler :refer :all]
            [reitit.ring :as ring]))

(def user-routers
  [["/users" {:get {:middleware [[wrap-content-type "application/json"]]
                   :handler get-users}
             :post {:middleware [[wrap-content-type "application/json"]]
                    :handler create-user}}]
  ["/users/:id" {:get {:middleware [[wrap-content-type "application/json"]]
                        :handler get-user}
                 :put {:middleware [[wrap-content-type "application/json"]]
                      :handler update-user}
                 :delete {:middleware [[wrap-content-type "application/json"]]
                         :handler delete-user}}]])

(def app
  (ring/ring-handler
   (ring/router
    ["/api"
     user-routers
     ])))

(app {:request-method :get, :uri "/api/users/1"})