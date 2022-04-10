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

#ifndef MQNIC_SELQ_H
#define MQNIC_SELQ_H

#include <linux/netdevice.h>
#include <linux/skbuff.h>
#include <linux/version.h>

#if LINUX_VERSION_CODE >= KERNEL_VERSION(4, 19, 0)
typedef u16 mqnic_selq_handler_func_t(struct sk_buff *skb, struct net_device *sb_dev);
#else
typedef u16 mqnic_selq_handler_func_t(struct sk_buff *skb, void *accel_priv);
#endif

bool mqnic_is_selq_handler_supported(struct net_device *ndev);
bool mqnic_is_selq_handler_busy(struct net_device *ndev);
int mqnic_selq_handler_register(struct net_device *ndev,
				mqnic_selq_handler_func_t *selq_handler,
				void *selq_handler_data);
void mqnic_selq_handler_unregister(struct net_device *ndev);

void *mqnic_selq_handler_data_get_rcu(const struct net_device *ndev);
void *mqnic_selq_handler_data_get_rtnl(const struct net_device *ndev);

#endif /* MQNIC_SELQ_H */
