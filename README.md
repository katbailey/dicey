Dicey Decision API
===================

REST API to post decision strategies and then get decisions for containers.

To post a new strategy, make a POST request to the /strategies endpoint with the following data:
- name (The machine name of the strategy)
- cid (The container ID this strategy applies to)
- options (An array of possible content URLs that can be returned by this strategy)

To get a decision for a particular container, make a GET request to the /decision endpoint with the following querystring params:
- cid (The container ID)
- pid (The person ID - can be any string)
The response from this request will be an array of URLs (currently always with only one element.)
