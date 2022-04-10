/* SPDX-License-Identifier: BSD-2-Clause-Views */
/*
 * Copyright 2021, Missing Link Electronics, Inc.
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
#include <linux/skbuff.h>
#include <linux/version.h>

#include "mqnic.h"
#include "mqnic_selq.h"

bool mqnic_selq_handler_enable = false;

module_param_named(selq_handler_enable, mqnic_selq_handler_enable, bool, 0444);
MODULE_PARM_DESC(selq_handler_enable, "enable select queue handler capability (default: false)");

#define __mqnic_is_selq_handler_available(ndev) \
	(ndev->netdev_ops->ndo_select_queue == &mqnic_select_queue)

/**
 *      mqnic_is_selq_handler_supported - check if select queue handler is
 *                                        supported
 *      @ndev: device to check
 *
 *      Check if a select queue handler is supported by a given device.
 *      Return true if it is supported.
 *
 *      The caller must hold the rtnl_mutex.
 */
bool mqnic_is_selq_handler_supported(struct net_device *ndev)
{
	ASSERT_RTNL();

	if (!ndev)
		return false;

	if (__mqnic_is_selq_handler_available(ndev))
		return true;
	else
		netdev_notice(ndev, "select queue handler support not available");

	return false;
}
EXPORT_SYMBOL(mqnic_is_selq_handler_supported);

/**
 *      mqnic_is_selq_handler_busy - check if select queue handler is registered
 *      @ndev: device to check
 *
 *      Check if a select queue handler is already registered for a given
 *      device.  Return true if there is one.
 *
 *      The caller must hold the rtnl_mutex.
 */
bool mqnic_is_selq_handler_busy(struct net_device *ndev)
{
	struct mqnic_priv *priv;

	ASSERT_RTNL();

	if (!ndev)
		return true;

	if (!__mqnic_is_selq_handler_available(ndev))
		return true;

	priv = netdev_priv(ndev);

	return rtnl_dereference(priv->selq_handler);
}
EXPORT_SYMBOL(mqnic_is_selq_handler_busy);

/**
 *      mqnic_selq_handler_register - register select queue handler
 *      @ndev: device to register a handler for
 *      @selq_handler: select queue handler to register
 *      @selq_handler_data: data pointer that is used by select queue handler
 *
 *      Register a select queue handler for a device. This handler will then be
 *      called from mqnic_select_queue(). A negative errno code is returned
 *      on a failure.
 *
 *      The caller must hold the rtnl_mutex.
 */
int mqnic_selq_handler_register(struct net_device *ndev,
				mqnic_selq_handler_func_t *selq_handler,
				void *selq_handler_data)
{
	struct mqnic_priv *priv;

	ASSERT_RTNL();

	if (mqnic_is_selq_handler_busy(ndev))
		return -EBUSY;

	priv = netdev_priv(ndev);

	/* Note: selq_handler_data must be set before selq_handler */
	rcu_assign_pointer(priv->selq_handler_data, selq_handler_data);
	rcu_assign_pointer(priv->selq_handler, selq_handler);

	return 0;
}
EXPORT_SYMBOL(mqnic_selq_handler_register);

/**
 *      mqnic_selq_handler_unregister - unregister select queue handler
 *      @ndev: device to unregister a handler from
 *
 *      Unregister a select queue handler from a device.
 *
 *      The caller must hold the rtnl_mutex.
 */
void mqnic_selq_handler_unregister(struct net_device *ndev)
{
	struct mqnic_priv *priv;

	ASSERT_RTNL();

	if (!ndev)
		return;

	if (!__mqnic_is_selq_handler_available(ndev))
		return;

	priv = netdev_priv(ndev);

	RCU_INIT_POINTER(priv->selq_handler, NULL);
	/* a reader seeing a non NULL selq_handler in a rcu_read_lock()
	 * section has a guarantee to see a non NULL selq_handler_data
	 * as well.
	 */
	synchronize_net();
	RCU_INIT_POINTER(priv->selq_handler_data, NULL);
}
EXPORT_SYMBOL(mqnic_selq_handler_unregister);

#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 2, 0)
u16 mqnic_select_queue(struct net_device *ndev, struct sk_buff *skb,
		       struct net_device *sb_dev)
#elif LINUX_VERSION_CODE >= KERNEL_VERSION(4, 19, 0)
u16 mqnic_select_queue(struct net_device *ndev, struct sk_buff *skb,
		       struct net_device *sb_dev,
		       select_queue_fallback_t fallback)
#else
u16 mqnic_select_queue(struct net_device *ndev, struct sk_buff *skb,
		       void *accel_priv,
		       select_queue_fallback_t fallback)
#endif
{
	struct mqnic_priv *priv = netdev_priv(ndev);
	mqnic_selq_handler_func_t *selq_handler;

	selq_handler = rcu_dereference(priv->selq_handler);
	if (selq_handler)
#if LINUX_VERSION_CODE >= KERNEL_VERSION(4, 19, 0)
		return selq_handler(skb, sb_dev);
#else
		return selq_handler(skb, accel_priv);
#endif

#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 2, 0)
	return netdev_pick_tx(ndev, skb, sb_dev);
#elif LINUX_VERSION_CODE >= KERNEL_VERSION(4, 19, 0)
	return fallback(ndev, skb, sb_dev);
#else
	return fallback(ndev, skb);
#endif
}

/* NOTE: Obviously these functions could better be "inline". However,
 * since this API is not included in net/core/, we need access to the driver-
 * specific struct, which results in the need for internal file "mqnic.h".
 */
void *mqnic_selq_handler_data_get_rcu(const struct net_device *ndev)
{
	struct mqnic_priv *priv = netdev_priv(ndev);

	return rcu_dereference(priv->selq_handler_data);
}
EXPORT_SYMBOL(mqnic_selq_handler_data_get_rcu);

void *mqnic_selq_handler_data_get_rtnl(const struct net_device *ndev)
{
	struct mqnic_priv *priv = netdev_priv(ndev);

	return rtnl_dereference(priv->selq_handler_data);
}
EXPORT_SYMBOL(mqnic_selq_handler_data_get_rtnl);
