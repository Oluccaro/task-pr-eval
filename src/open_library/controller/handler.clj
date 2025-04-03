(ns open-library.controller.handler
  (:require [cheshire.core :refer :all])
  (:gen-class))

(defn get-users [request]
  {:status 200, :body (generate-string {"users" [{"id" 1 "name" "bob"} {"id" 2 "name" "juca"}]})})

(defn get-user [request]
  (let [{:keys [id name]} (:path-params request)]
    {:status 200, :body (generate-string {"user" [{"id" id "name" name}]})}))

(defn create-user [request]
  {:status 201, :body "{user 1}"})

(defn update-user [request]
  (let [{:keys [id name]} (:path-params request)]
    {:status 200, :body (generate-string {"user" [{"id" id "name" name}]})}))

(defn delete-user [request]
  (let [[id] (:id (:path-params request))]
    {:status 200, :body (generate-string {"user" [{"id" 1 "name" "bob"}]})}))

