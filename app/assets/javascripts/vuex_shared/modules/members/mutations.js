import Vue from 'vue';
import { s__ } from '~/locale';
import * as types from './mutation_types';
import { findMember } from './utils';

export default {
  [types.RECEIVE_MEMBER_ROLE_SUCCESS](state, { memberId, accessLevel }) {
    const member = findMember(state, memberId);

    if (!member) {
      return;
    }

    Vue.set(member, 'accessLevel', accessLevel);
  },
  [types.RECEIVE_MEMBER_ROLE_ERROR](state) {
    state.errorMessage = s__(
      "Members|An error occurred while updating the member's role, please try again.",
    );
    state.showError = true;
  },
  [types.HIDE_ERROR](state) {
    state.showError = false;
    state.errorMessage = '';
  },
};
