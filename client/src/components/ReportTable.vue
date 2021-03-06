<template>
  <div>
    <v-toolbar flat>
      <v-btn :disabled="!btnNewRecordDisabled" class="mb-2" @click="currentWeek">
        today
      </v-btn>
      <v-btn fab small @click="previousWeek">
        <v-icon>
          skip_previous
        </v-icon>
      </v-btn>
      <v-btn fab small @click="nextWeek">
        <v-icon>
          skip_next
        </v-icon>
      </v-btn>
      <v-flex xs2>
        <v-label class="text-xs-center">
          {{ formatWeek(dateFrom) }} - {{ formatWeek(dateTo) }}
        </v-label>
      </v-flex>
      <v-label>Weekly: {{ reportedThisWeek }} hours</v-label>
      <v-spacer />
      <v-toolbar-title>
        <v-text-field v-model="search" clearable append-icon="search" label="Search" single-line />
      </v-toolbar-title>
      <v-spacer />
      <v-btn color="primary" :disabled="btnNewRecordDisabled" class="mb-2" @click="addItem">
        new record
      </v-btn>
    </v-toolbar>
    <v-data-table :headers="headers" :items="selectedReportedHours" :search="search" :loading="loading" class="elevation-1" :rows-per-page-items="rowsPerPage">
      <template slot="items" slot-scope="props">
        <td>
          <!-- <v-menu :value="props.item.date" :close-on-content-click="true" :nudge-right="40" lazy transition="scale-transition" offset-y full-width min-width="290px"> -->
          <v-menu :close-on-content-click="true" :nudge-right="40" lazy transition="scale-transition" offset-y full-width min-width="290px" @keyup.esc="model = false">
            <v-text-field slot="activator" :value="formatDate(props.item.date)" prepend-icon="today" readonly class="body-1" />
            <v-date-picker first-day-of-week="1" :value="props.item.date" @input="onUpdateDate({id: props.item.id, date: $event})" />
          </v-menu>
        </td>
        <td class="text-xs-left">
          <v-edit-dialog :return-value="props.item.hours" lazy>
            {{ props.item.hours }}
            <v-text-field slot="input" :value="props.item.hours" label="Hours" single-line :rules="[ruleFloat]"
                          type="number" min="0" max="20" step="0.5" maxlength="2"
                          @change="onUpdateHours({id: props.item.id, hours: $event})"
            />
          </v-edit-dialog>
        </td>
        <td class="text-xs-left">
          <v-edit-dialog :return-value="props.item.project" lazy>
            {{ props.item.project }}
            <v-select slot="input" :value="props.item.project" item-text="name" item-value="name"
                      :items="assignedProjects" label="Project" :dense="true" :hide-selected="false"
                      @change="onUpdateProject({id: props.item.id, project: $event})"
            />
          </v-edit-dialog>
        </td>
        <td class="text-xs-left">
          <v-edit-dialog :return-value="props.item.description" lazy>
            {{ props.item.description }}
            <v-text-field slot="input" :value="props.item.description" :rules="[ruleMax100chars]" label="Description" single-line
                          counter @change="onUpdateDescription({id: props.item.id, description: $event})"
            />
          </v-edit-dialog>
        </td>
        <td class="text-xs-left">
          <v-edit-dialog :return-value="props.item.rate" lazy>
            {{ props.item.rate }}
            <v-select slot="input" :value="props.item.rate" item-text="name" item-value="name"
                      :items="rates" label="Rate" :dense="true" :hide-selected="false"
                      @change="onUpdateRate({id: props.item.id, rate: $event})"
            />
          </v-edit-dialog>
        </td>
        <td class="justify-center layout px-0">
          <v-icon small class="mr-2" @click="duplicateItem(props.item)">
            file_copy
          </v-icon>
          <v-icon small @click="deleteItem(props.item)">
            delete
          </v-icon>
        </td>
      </template>
      <template slot="no-data">
        <v-alert :value="true" color="info" icon="info">
          No reported hours this week :(
        </v-alert>
      </template>
    </v-data-table>
    <!-- Dialog if use attempts to edit previous weeks without unlocking -->
    <v-dialog v-model="dialogEditingUnlockedWeek" width="30%">
      <v-card>
        <v-card-title class="headline">
          Editing the previous week
        </v-card-title>

        <v-card-text multiline>
          Data might be already reported to the clients.
          Do you want to unlock editing of previous weeks and repeat the edit?
        </v-card-text>

        <v-card-actions>
          <v-spacer />

          <v-btn color="blue darken-1" flat="flat" @click="unlockPreviousWeeks">
            Unlock
          </v-btn>

          <v-btn color="primary" dark class="mb-2" @click="dialogEditingUnlockedWeek = false">
            Cancel
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </div>
</template>

<script>
  import { mapState } from 'vuex'
  import moment from 'moment-timezone'

  export default {
    data: () => ({
      search: '',
      dialogEditingUnlockedWeek: false,
      ruleMax100chars: v => v.length <= 100 || v.length + ' / 100',
      ruleFloat: v => !isNaN(parseFloat(v)) || 'Input should be a muber with one decimal',
      repDate: '',
      rowsPerPage: [ 30, 50, { 'text': '$vuetify.dataIterator.rowsPerPageAll', 'value': -1 } ],
      headers: [
        { text: 'Date', align: 'left', sortable: true, value: 'date', class: 'body-1' },
        { text: 'Hours', align: 'left', sortable: true, value: 'hours', class: 'body-1' },
        { text: 'Project', align: 'left', sortable: true, value: 'project', class: 'body-1' },
        { text: 'Description', align: 'left', value: 'description', class: 'body-1' },
        { text: 'Rate', align: 'left', sortable: true, value: 'rate', class: 'body-1' },
        { text: 'Actions', align: 'center', sortable: false, value: 'actions', class: 'body-1' }
      ],
      reported: []
    }),

    computed: {
      btnNewRecordDisabled () {
        if (this.previousWeeksUnLock) {
          return false
        }
        let today = moment.tz({}, 'Europe/Prague')
        if (today.isBetween(this.dateFrom, this.dateTo, null, '[]')) {
          return false
        }
        return true
      },
      formTitle () {
        return this.editedIndex === -1 ? 'New Record' : 'Edit Record'
      },
      selectedReportedHours () {
        return this.reportedHours.filter(report => {
          let d = new Date(report.date)
          return (d >= this.dateFrom && d <= this.dateTo && report.consultant === this.selectedConsultants)
        })
      },
      reportedThisWeek () {
        let rep = 0.0
        for (let i = 0; i < this.selectedReportedHours.length; i++) {
          rep = rep + this.selectedReportedHours[i].hours
        }
        return rep
      },
      previousWeeksUnLock: {
        set () {
          this.$store.dispatch('context/TogglePreviousWeeksUnLock')
        },
        get () {
          return this.$store.state.context.previousWeeksUnLock
        }
      },
      ...mapState({
        reportedHours: state => state.reportedHours.all,
        loading: state => state.reportedHours.loading,
        dateFrom: state => state.context.dateFrom,
        dateTo: state => state.context.dateTo,
        dateMonth: state => state.context.dateMonth,
        assignedProjects: state => state.projects.all,
        rates: state => state.rates.all,
        selectedConsultants: state => state.consultants.selected
      })
    },

    watch: {
      dialog (val) {
        val || this.close()
      }
    },

    created () {
      this.$store.commit('context/SET_PAGE', 'Reported hours')
    },

    methods: {
      currentWeek () {
        this.$store.dispatch('context/jumpToWeek', moment.tz({}, 'Europe/Prague'))
      },
      editPreviousWeeks (itemID) {
        const editedDay = moment(this.selectedReportedHours.filter(item => item.id === itemID)[0].date)
        if (this.previousWeeksUnLock) {
          return true
        } else {
          if (editedDay.isBetween(moment.tz({}, 'Europe/Prague').startOf('isoWeek'), moment.tz({}, 'Europe/Prague').endOf('isoWeek'), null, '[]')) {
            return true
          }
        }
        this.dialogEditingUnlockedWeek = true
        return false
      },
      unlockPreviousWeeks () {
        this.previousWeeksUnLock = true
        this.dialogEditingUnlockedWeek = false
      },
      onUpdateProject (newValue) {
        if (this.editPreviousWeeks(newValue.id)) {
          let payload = {
            id: newValue.id,
            type: 'project',
            value: newValue.project
          }
          this.$store.dispatch('reportedHours/updateAttributeValue', payload)
        }
      },
      onUpdateDate (newValue) {
        if (this.editPreviousWeeks(newValue.id)) {
          let payload = {
            id: newValue.id,
            type: 'date',
            value: newValue.date
          }
          this.$store.dispatch('reportedHours/updateAttributeValue', payload)
        }
      },
      onUpdateHours (newValue) {
        if (this.editPreviousWeeks(newValue.id)) {
          let payload = {
            id: newValue.id,
            type: 'hours',
            value: parseFloat(newValue.hours)
          }
          this.$store.dispatch('reportedHours/updateAttributeValue', payload)
        }
      },
      onUpdateDescription (newValue) {
        if (this.editPreviousWeeks(newValue.id)) {
          let payload = {
            id: newValue.id,
            type: 'description',
            value: newValue.description
          }
          this.$store.dispatch('reportedHours/updateAttributeValue', payload)
        }
      },
      onUpdateRate (newValue) {
        if (this.editPreviousWeeks(newValue.id)) {
          let payload = {
            id: newValue.id,
            type: 'rate',
            value: newValue.rate
          }
          this.$store.dispatch('reportedHours/updateAttributeValue', payload)
        }
      },
      formatDate (date) {
        if (!date) return null
        return moment(date).format('ddd, MMM Do')
      },
      addItem (item) {
        let newRecord = {}
        newRecord.id = null
        newRecord.consultant = this.selectedConsultants
        newRecord.date = this.dateFrom.format('YYYY-MM-DDTHH:mm:ssZ')
        newRecord.hours = 8
        newRecord.rate = 'Off-site'
        newRecord.project = ''
        this.$store.dispatch('reportedHours/addRecord', newRecord)
      },
      duplicateItem (item) {
        if (this.editPreviousWeeks(item.id)) {
          let newRecord = Object.assign({}, item)
          newRecord.id = null
          newRecord.date = moment(item.date).format('YYYY-MM-DDTHH:mm:ssZ')
          this.$store.dispatch('reportedHours/addRecord', newRecord)
        }
      },
      deleteItem (item) {
        if (this.editPreviousWeeks(item.id)) {
          confirm('Are you sure you want to delete the record?') && this.$store.dispatch('reportedHours/removeRecord', parseInt(item.id, 10))
          this.$store.dispatch('context/setNotification', { text: this.formatDate(item.date) + ', ' + item.hours + ' hrs - record deleted', type: 'success' })
        }
      },
      previousWeek () {
        this.$store.dispatch('context/changeWeek', 'previous')
      },
      nextWeek () {
        this.$store.dispatch('context/changeWeek', 'next')
      },
      formatWeek (date) {
        let a = moment(date, 'YYYY-MM-DD').format('MMM Do')
        return a
      }
    }
  }
</script>

<style>
/* workaround to decrease spacing of date field using elements v-menu amnd v-text-field */
table .v-messages.theme--light {
  display: none;
}
table .v-input--is-readonly.theme--light {
  padding-top: 0px !important;
  margin-top: 0px !important;
}
</style>
