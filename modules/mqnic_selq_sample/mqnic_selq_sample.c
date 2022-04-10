/* SPDX-License-Identifier: BSD-2-Clause-Views */
/*
 * Copyright 2022, Missing Link Electronics, Inc.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 *    1. Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *
 *    2. Redistributions in binary form must reproduce the above
 *       copyright notice, this list of conditions and the following
 *       disclaimer in the documentation and/or other materials provided
 *       with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * The views and conclusions contained in the software and documentation
 * are those of the authors and should not be interpreted as representing
 * official policies, either expressed or implied, of Missing Link
 * Electronics, Inc.
 */

#include <linux/module.h>
#include <linux/netdevice.h>
#include <linux/rtnetlink.h>

#include <mqnic_selq.h>

char *mqnic_selq_sample_ifname = NULL;
unsigned short mqnic_selq_sample_queue = 0;
bool mqnic_selq_sample_usedata = false;

module_param_named(ifname, mqnic_selq_sample_ifname, charp, 0444);
MODULE_PARM_DESC(ifname, "name of network interface to select queue on (default: none)");
module_param_named(queue, mqnic_selq_sample_queue, ushort, 0444);
MODULE_PARM_DESC(queue, "static queue index to select (default: 0)");
module_param_named(usedata, mqnic_selq_sample_usedata, bool, 0444);
MODULE_PARM_DESC(usedata, "enable usage of private data pointer (default: false)");

struct net_device *ndev;

/* called under rcu_read_lock_bh() from dev_queue_xmit() */
#if LINUX_VERSION_CODE >= KERNEL_VERSION(4, 19, 0)
u16 mqnic_selq_sample_handler(struct sk_buff *skb, struct net_device *sb_dev)
#else
u16 mqnic_selq_sample_handler(struct sk_buff *skb, void *accel_priv)
#endif
{
	/* NOTE: If private data has been associated with a registered handler,
	 * such a private data pointer can be retrieved by either
	 *   mqnic_selq_handler_data_get_rcu(const struct net_device *)
	 * or
	 *   mqnic_selq_handler_data_get_rntl(const struct net_device *)
	 * depending on context.
	 */

	return mqnic_selq_sample_queue;
}

#if LINUX_VERSION_CODE >= KERNEL_VERSION(4, 19, 0)
u16 mqnic_selq_sample_handler_usedata(struct sk_buff *skb, struct net_device *sb_dev)
#else
u16 mqnic_selq_sample_handler_usedata(struct sk_buff *skb, void *accel_priv)
#endif
{
	unsigned short *pqueue;

	pqueue = mqnic_selq_handler_data_get_rcu(skb->dev);
	return *pqueue;
}

static int __init mqnic_selq_sample_init(void)
{
	int rc;
	mqnic_selq_handler_func_t *handler;
	void *handler_data;

	if (!mqnic_selq_sample_ifname) {
		pr_err("%s: missing argument ifname\n", THIS_MODULE->name);
		return -EINVAL;
	}

	ndev = dev_get_by_name(&init_net, mqnic_selq_sample_ifname);
	if (!ndev) {
		pr_err("%s: failed to find network interface \"%s\"\n",
				THIS_MODULE->name, mqnic_selq_sample_ifname);
		return -EINVAL;
	}

	rtnl_lock();

	if (!mqnic_is_selq_handler_supported(ndev)) {
		pr_err("%s: network interface \"%s\" misses support for TX select queue handler\n",
				THIS_MODULE->name, mqnic_selq_sample_ifname);
		rc = -EINVAL;
		goto err;
	}

	if (mqnic_is_selq_handler_busy(ndev)) {
		pr_err("%s: network interface \"%s\" already has TX select queue handler registered with it\n",
				THIS_MODULE->name, mqnic_selq_sample_ifname);
		rc = -EBUSY;
		goto err;
	}

	if (!mqnic_selq_sample_usedata) {
		handler = mqnic_selq_sample_handler;
		handler_data = NULL;
	} else {
		handler = mqnic_selq_sample_handler_usedata;
		handler_data = &mqnic_selq_sample_queue;
	}
	rc = mqnic_selq_handler_register(ndev, handler,	handler_data);
	if (rc) {
		pr_err("%s: failed to register selq handler with network interface \"%s\"",
				THIS_MODULE->name, mqnic_selq_sample_ifname);
		goto err;
	}

	pr_info("%s: attached to network interface \"%s\", directing traffic to queue %hu, %susing private data\n",
			THIS_MODULE->name, mqnic_selq_sample_ifname,
			mqnic_selq_sample_queue,
			mqnic_selq_sample_usedata ? "" : "not ");

	goto out;

err:
	dev_put(ndev);
out:
	rtnl_unlock();
	return rc;
}

static void __exit mqnic_selq_sample_exit(void)
{
	rtnl_lock();
	mqnic_selq_handler_unregister(ndev);
	rtnl_unlock();

	dev_put(ndev);

	pr_info("%s: detached from network interface \"%s\"\n",
			THIS_MODULE->name, mqnic_selq_sample_ifname);
}

module_init(mqnic_selq_sample_init);
module_exit(mqnic_selq_sample_exit);

MODULE_DESCRIPTION("mqnic TX select queue handler example");
MODULE_AUTHOR("Missing Link Electronics, "
	      "Joachim Foerster <joachim.foerster@missinglinkelectronics.com>");
MODULE_LICENSE("Dual BSD/GPL");
MODULE_VERSION("0.1");
